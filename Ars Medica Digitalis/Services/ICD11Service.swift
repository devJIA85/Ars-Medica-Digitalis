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
import OSLog

actor ICD11Service {

    private nonisolated let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "ICD11Cache")

    // MARK: - Init

    init() {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            cacheDirectory = nil
            return
        }
        let dir = base.appendingPathComponent(cacheFolderName, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            cacheDirectory = dir
            return
        }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            cacheDirectory = dir
        } catch {
            cacheDirectory = nil
        }
    }

    // MARK: - Singleton

    static let shared = ICD11Service()

    // MARK: - Token OAuth2

    private var cachedToken: String?
    private var tokenExpiration: Date?

    // MARK: - Cache de búsqueda

    /// Cache en memoria de resultados, indexado por "query|offset|limit".
    /// Nivel 1 del sistema de cache (Nivel 2 es el snapshot en SwiftData).
    private var searchCache: [String: [ICD11SearchResult]] = [:]

    // MARK: - Cache persistente (disco)

    private let cacheFolderName = "ICD11SearchCache"

    /// URL del directorio de caché en disco. Se computa una sola vez en `init()`
    /// para evitar dos syscalls (fileExists + createDirectory) en cada acceso.
    private let cacheDirectory: URL?

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

        let cacheKey = "\(trimmed.lowercased())|\(offset)|\(limit)|\(language)"
        if let cached = searchCache[cacheKey] {
            return cached
        }

        let diskCached = loadSearchCache(for: cacheKey)
        if let diskCached {
            searchCache[cacheKey] = diskCached
        }

        do {
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
                let results = try await parseSearchResults(from: retryData)
                searchCache[cacheKey] = results
                saveSearchCache(results, for: cacheKey)
                return results
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw ICD11Error.httpError(statusCode: httpResponse.statusCode)
            }

            let results = try await parseSearchResults(from: data)
            searchCache[cacheKey] = results
            saveSearchCache(results, for: cacheKey)
            return results
        } catch {
            if let diskCached {
                return diskCached
            }
            throw error
        }
    }

    /// Limpia la cache de búsqueda en memoria.
    func clearCache() {
        searchCache.removeAll()
        clearDiskCache()
    }

    // MARK: - Cache persistente (disco)

    private func loadSearchCache(for cacheKey: String) -> [ICD11SearchResult]? {
        guard let url = cacheFileURL(for: cacheKey),
              let data = try? Data(contentsOf: url) else {
            return nil  // cache miss — comportamiento esperado
        }
        do {
            return try JSONDecoder().decode([ICD11SearchResult].self, from: data)
        } catch {
            logger.warning("ICD11 cache decode failed for key \(cacheKey, privacy: .public): \(error)")
            return nil
        }
    }

    private func saveSearchCache(_ results: [ICD11SearchResult], for cacheKey: String) {
        guard let url = cacheFileURL(for: cacheKey) else { return }
        do {
            let data = try JSONEncoder().encode(results)
            try data.write(to: url, options: [.atomic])
        } catch {
            logger.warning("ICD11 cache write failed for key \(cacheKey, privacy: .public): \(error)")
        }
    }

    private func clearDiskCache() {
        guard let directory = cacheDirectory else { return }
        do {
            let cachedFiles = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            for fileURL in cachedFiles {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            logger.warning("ICD11 cache clear failed: \(error)")
        }
    }

    private func cacheFileURL(for cacheKey: String) -> URL? {
        cacheDirectory?.appendingPathComponent(cacheFileName(for: cacheKey))
    }

    private func cacheFileName(for cacheKey: String) -> String {
        let base64 = Data(cacheKey.utf8).base64EncodedString()
        let safe = base64
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return "search-\(safe).json"
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

    /// Carga client_id y client_secret desde el Keychain del dispositivo.
    /// En el primer uso migra automáticamente desde `ICD11Config.plist`.
    private func loadCredentials() throws -> APICredentials {
        let stored = try ICD11KeychainStore.loadCredentials()
        return APICredentials(clientId: stored.clientId, clientSecret: stored.clientSecret)
    }

    // MARK: - Parseo JSON

    /// Parsea el JSON de búsqueda extrayendo destinationEntities.
    /// Usa parseo manual porque la API devuelve campos opcionales
    /// inconsistentes — un campo inválido no debe romper todo el resultado.
    /// @concurrent: parseo CPU-bound puro, no accede estado del actor.
    /// Corre en el thread pool cooperativo liberando el actor durante el parseo.
    @concurrent
    private func parseSearchResults(from data: Data) async throws -> [ICD11SearchResult] {
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
