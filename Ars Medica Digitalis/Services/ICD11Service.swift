//
//  ICD11Service.swift
//  Ars Medica Digitalis
//
//  Actor que encapsula toda comunicación con la API del CIE-11 de la OMS.
//  Gestiona internamente el token OAuth2 y cachea resultados de búsqueda
//  en memoria durante la sesión activa del usuario.
//
//  Declarado como actor porque las operaciones de red son I/O puro
//  que no necesitan el MainActor. Las funciones de red llevan @concurrent
//  para paralelismo real según Approachable Concurrency (Swift 6.2).
//

import Foundation

actor ICD11Service {

    // MARK: - Singleton

    static let shared = ICD11Service()

    // MARK: - Token OAuth2

    private var cachedToken: String?
    private var tokenExpiration: Date?

    // MARK: - Cache de búsqueda

    /// Cache en memoria de resultados, indexado por "query|offset|limit".
    /// Nivel 1 del sistema de cache (Nivel 2 es el snapshot en SwiftData).
    private var searchCache: [String: [ICD11SearchResult]] = [:]

    // MARK: - Configuración

    /// Versión del release MMS a consultar
    private let releaseVersion = "2024-01"

    private var searchBaseURL: String {
        "https://id.who.int/icd/release/11/\(releaseVersion)/mms/search"
    }

    private let tokenURL = "https://icdaccessmanagement.who.int/connect/token"

    // MARK: - API Pública

    /// Busca diagnósticos en la linearización MMS del CIE-11.
    /// Requiere mínimo 3 caracteres para evitar consultas demasiado amplias.
    func search(
        query: String,
        offset: Int = 0,
        limit: Int = 25,
        language: String = "es"
    ) async throws -> [ICD11SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return [] }

        let cacheKey = "\(trimmed.lowercased())|\(offset)|\(limit)"
        if let cached = searchCache[cacheKey] {
            return cached
        }

        let token = try await validToken()

        guard var components = URLComponents(string: searchBaseURL) else {
            throw ICD11Error.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "flatResults", value: "true"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        guard let url = components.url else {
            throw ICD11Error.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("v2", forHTTPHeaderField: "API-Version")
        request.setValue(language, forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ICD11Error.invalidResponse
        }

        // Si el token expiró durante la request, renovar y reintentar una vez
        if httpResponse.statusCode == 401 {
            cachedToken = nil
            tokenExpiration = nil
            let newToken = try await validToken()
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
            guard let retryHTTP = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHTTP.statusCode) else {
                throw ICD11Error.authenticationFailed
            }
            let results = try parseSearchResults(from: retryData)
            searchCache[cacheKey] = results
            return results
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ICD11Error.httpError(statusCode: httpResponse.statusCode)
        }

        let results = try parseSearchResults(from: data)
        searchCache[cacheKey] = results
        return results
    }

    /// Limpia la cache de búsqueda en memoria.
    func clearCache() {
        searchCache.removeAll()
    }

    // MARK: - Gestión de Token (privado)

    /// Devuelve un token válido, renovándolo proactivamente si expiró.
    private func validToken() async throws -> String {
        if let token = cachedToken,
           let expiration = tokenExpiration,
           expiration > Date() {
            return token
        }
        return try await fetchNewToken()
    }

    /// Solicita un nuevo token OAuth2 al servidor de la OMS.
    /// Las credenciales se cargan desde ICD11Config.plist.
    private func fetchNewToken() async throws -> String {
        let credentials = try loadCredentials()

        guard let url = URL(string: tokenURL) else {
            throw ICD11Error.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type=client_credentials",
            "client_id=\(credentials.clientId)",
            "client_secret=\(credentials.clientSecret)",
            "scope=icdapi_access"
        ]
        request.httpBody = bodyParams.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ICD11Error.authenticationFailed
        }

        let decoded = try JSONDecoder().decode(ICD11TokenResponse.self, from: data)

        // Cachear con margen de 60 segundos antes de la expiración real
        cachedToken = decoded.access_token
        tokenExpiration = Date().addingTimeInterval(TimeInterval(decoded.expires_in - 60))

        return decoded.access_token
    }

    // MARK: - Credenciales

    private struct APICredentials {
        let clientId: String
        let clientSecret: String
    }

    /// Carga client_id y client_secret desde ICD11Config.plist.
    /// Este archivo debe existir en el bundle pero NO estar versionado en git.
    private func loadCredentials() throws -> APICredentials {
        guard let url = Bundle.main.url(forResource: "ICD11Config", withExtension: "plist") else {
            throw ICD11Error.missingConfiguration(
                "ICD11Config.plist no encontrado en el bundle. "
                + "Crear el archivo con las claves 'clientId' y 'clientSecret'."
            )
        }

        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ) as? [String: String],
              let clientId = dict["clientId"],
              let clientSecret = dict["clientSecret"] else {
            throw ICD11Error.missingConfiguration(
                "ICD11Config.plist debe contener 'clientId' y 'clientSecret' como String."
            )
        }

        return APICredentials(clientId: clientId, clientSecret: clientSecret)
    }

    // MARK: - Parseo JSON

    /// Parsea el JSON de búsqueda extrayendo destinationEntities.
    /// Usa parseo manual porque la API devuelve campos opcionales
    /// inconsistentes — un campo inválido no debe romper todo el resultado.
    private func parseSearchResults(from data: Data) throws -> [ICD11SearchResult] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entities = root["destinationEntities"] as? [[String: Any]] else {
            throw ICD11Error.parsingFailed
        }

        return entities.compactMap { dict -> ICD11SearchResult? in
            guard let id = dict["id"] as? String,
                  let titleHTML = dict["title"] as? String else {
                return nil
            }

            return ICD11SearchResult(
                id: id,
                theCode: dict["theCode"] as? String,
                title: titleHTML.cleanedHTMLTags(),
                chapter: dict["chapter"] as? String,
                score: (dict["score"] as? NSNumber)?.doubleValue
            )
        }
    }
}

// MARK: - Errores

/// Errores específicos de la integración con CIE-11.
enum ICD11Error: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case httpError(statusCode: Int)
    case parsingFailed
    case missingConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "URL de la API CIE-11 inválida."
        case .invalidResponse:
            "Respuesta inesperada del servidor."
        case .authenticationFailed:
            "No se pudo autenticar con la API CIE-11. Verificar credenciales."
        case .httpError(let code):
            "Error HTTP \(code) al consultar la API CIE-11."
        case .parsingFailed:
            "No se pudo interpretar la respuesta de la API CIE-11."
        case .missingConfiguration(let detail):
            detail
        }
    }
}
