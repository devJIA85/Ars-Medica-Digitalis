#!/usr/bin/env swift
//
//  icd11_seed_generator.swift
//  Ars Medica Digitalis
//
//  Script standalone para generar el catálogo CIE-11 MMS completo en español.
//  Recorre recursivamente el árbol MMS vía la API de la OMS y produce
//  un archivo JSON que se incluye en el bundle de la app para búsqueda offline.
//
//  Uso:
//    swift Scripts/icd11_seed_generator.swift
//
//  Prerequisitos:
//    - Ejecutar desde la raíz del proyecto (donde está ICD11Config.plist)
//    - Conexión a internet
//
//  Salida:
//    Scripts/icd11_mms_es.json (~3-8 MB)
//
//  Duración estimada:
//    - Contra API live con throttle 3 req/s: ~3-4 horas
//    - Contra Docker local sin throttle: ~5-10 minutos
//
//  Para usar Docker local:
//    docker run -p 80:80 -e acceptLicense=true -e saveAnalytics=false -e include=2024-01_es whoicd/icd-api
//    swift Scripts/icd11_seed_generator.swift --base-url http://localhost
//

import Foundation

// MARK: - Configuración

let releaseVersion = "2024-01"
let language = "es"
// Requests por segundo (conservador para API live)
let requestsPerSecond: Double = 3.0
let tokenURL = "https://icdaccessmanagement.who.int/connect/token"

// Permitir override de base URL para Docker local
var baseURL = "https://id.who.int"
if CommandLine.arguments.contains("--base-url"),
   let idx = CommandLine.arguments.firstIndex(of: "--base-url"),
   idx + 1 < CommandLine.arguments.count {
    baseURL = CommandLine.arguments[idx + 1]
    print("📦 Usando base URL personalizada: \(baseURL)")
}

let mmsRootURL = "\(baseURL)/icd/release/11/\(releaseVersion)/mms"

// MARK: - Tipos

struct SeedEntry: Codable {
    let code: String
    let title: String
    let uri: String
    let classKind: String
    let chapterCode: String
}

// MARK: - Estado global

var allEntries: [SeedEntry] = []
var visitedURIs: Set<String> = []
var token: String = ""
var totalRequests = 0
var errorCount = 0

// MARK: - Credenciales

func loadCredentials() -> (clientId: String, clientSecret: String) {
    // Buscar ICD11Config.plist en el subdirectorio de la app
    let plistPath = "Ars Medica Digitalis/ICD11Config.plist"
    guard FileManager.default.fileExists(atPath: plistPath),
          let data = FileManager.default.contents(atPath: plistPath),
          let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String],
          let clientId = dict["clientId"],
          let clientSecret = dict["clientSecret"] else {
        fatalError("❌ No se encontró ICD11Config.plist o faltan credenciales. Ejecutar desde la raíz del proyecto.")
    }
    return (clientId, clientSecret)
}

// MARK: - OAuth2 Token

func fetchToken() {
    let credentials = loadCredentials()

    guard let url = URL(string: tokenURL) else {
        fatalError("❌ URL de token inválida")
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    let body = [
        "grant_type=client_credentials",
        "client_id=\(credentials.clientId)",
        "client_secret=\(credentials.clientSecret)",
        "scope=icdapi_access"
    ].joined(separator: "&")
    request.httpBody = body.data(using: .utf8)

    let semaphore = DispatchSemaphore(value: 0)
    var tokenResult: String?

    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            print("❌ Error obteniendo token: \(error?.localizedDescription ?? "respuesta inválida")")
            return
        }
        tokenResult = accessToken
    }.resume()

    semaphore.wait()

    guard let t = tokenResult else {
        fatalError("❌ No se pudo obtener token OAuth2")
    }
    token = t
    print("🔑 Token obtenido exitosamente")
}

// MARK: - HTTP GET con throttle

func httpGet(urlString: String) -> [String: Any]? {
    guard let url = URL(string: urlString) else { return nil }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("v2", forHTTPHeaderField: "API-Version")
    request.setValue(language, forHTTPHeaderField: "Accept-Language")

    // Throttle
    Thread.sleep(forTimeInterval: 1.0 / requestsPerSecond)

    let semaphore = DispatchSemaphore(value: 0)
    var result: [String: Any]?
    var httpStatusCode = 0

    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        if let httpResponse = response as? HTTPURLResponse {
            httpStatusCode = httpResponse.statusCode
        }
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        result = json
    }.resume()

    semaphore.wait()
    totalRequests += 1

    // Retry en 401 (token expirado)
    if httpStatusCode == 401 {
        print("🔄 Token expirado, renovando...")
        fetchToken()
        return httpGet(urlString: urlString)
    }

    if result == nil {
        errorCount += 1
        if errorCount % 10 == 0 {
            print("⚠️  \(errorCount) errores acumulados")
        }
    }

    return result
}

// MARK: - Traversal recursivo

func traverseEntity(uri: String, chapterCode: String) {
    // Evitar ciclos
    guard !visitedURIs.contains(uri) else { return }
    visitedURIs.insert(uri)

    guard let json = httpGet(urlString: uri) else {
        print("⚠️  No se pudo obtener: \(uri)")
        return
    }

    // Extraer datos de la entidad
    let entityURI = json["@id"] as? String ?? uri
    let classKind = json["classKind"] as? String ?? ""

    // El título puede ser un String directo o un dict {"@language": "es", "@value": "..."}
    var title = ""
    if let titleDict = json["title"] as? [String: Any] {
        title = titleDict["@value"] as? String ?? ""
    } else if let titleStr = json["title"] as? String {
        title = titleStr
    }

    // El código MMS
    let code = json["code"] as? String ?? json["codeRange"] as? String ?? json["blockId"] as? String ?? ""

    // Determinar chapterCode: si es un capítulo, el código es su propio code
    let currentChapterCode: String
    if classKind == "chapter" {
        currentChapterCode = code
    } else {
        currentChapterCode = chapterCode
    }

    // Solo guardar entradas con código o título (skip entidades vacías)
    if !title.isEmpty {
        let entry = SeedEntry(
            code: code,
            title: cleanHTML(title),
            uri: entityURI,
            classKind: classKind,
            chapterCode: currentChapterCode
        )
        allEntries.append(entry)
    }

    // Progreso
    if allEntries.count % 500 == 0 && allEntries.count > 0 {
        print("📊 \(allEntries.count) entradas recolectadas (\(totalRequests) requests)")
    }

    // Recurrir a hijos
    if let children = json["child"] as? [String] {
        for childURI in children {
            traverseEntity(uri: childURI, chapterCode: currentChapterCode)
        }
    }
}

// MARK: - Limpieza HTML

func cleanHTML(_ text: String) -> String {
    // Remover etiquetas HTML simples que la API puede incluir
    var result = text
    let tagPattern = "<[^>]+>"
    if let regex = try? NSRegularExpression(pattern: tagPattern) {
        result = regex.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: ""
        )
    }
    // Decodificar entidades HTML comunes
    result = result.replacingOccurrences(of: "&amp;", with: "&")
    result = result.replacingOccurrences(of: "&lt;", with: "<")
    result = result.replacingOccurrences(of: "&gt;", with: ">")
    result = result.replacingOccurrences(of: "&quot;", with: "\"")
    result = result.replacingOccurrences(of: "&#39;", with: "'")
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Main

print("🚀 ICD-11 MMS Seed Generator")
print("   Release: \(releaseVersion)")
print("   Idioma: \(language)")
print("   Base URL: \(baseURL)")
print("   Throttle: \(requestsPerSecond) req/s")
print("")

// 1. Obtener token
fetchToken()

// 2. Obtener capítulos raíz
print("📥 Obteniendo capítulos raíz...")
guard let root = httpGet(urlString: mmsRootURL),
      let chapters = root["child"] as? [String] else {
    fatalError("❌ No se pudieron obtener los capítulos raíz del MMS")
}
print("📋 \(chapters.count) capítulos encontrados")
print("")

// 3. Recorrer recursivamente cada capítulo
for (index, chapterURI) in chapters.enumerated() {
    print("📖 Capítulo \(index + 1)/\(chapters.count): \(chapterURI.suffix(20))...")
    traverseEntity(uri: chapterURI, chapterCode: "")
    print("   ✅ Acumuladas: \(allEntries.count) entradas")
}

// 4. Escribir JSON
print("")
print("💾 Escribiendo JSON...")

let outputPath = "Scripts/icd11_mms_es.json"
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

do {
    let data = try encoder.encode(allEntries)
    let url = URL(fileURLWithPath: outputPath)
    try data.write(to: url)

    let fileSize = Double(data.count) / 1_000_000.0
    print("")
    print("✅ Completado!")
    print("   📄 Archivo: \(outputPath)")
    print("   📊 Entradas totales: \(allEntries.count)")
    print("   📦 Tamaño: \(String(format: "%.1f", fileSize)) MB")
    print("   🌐 Requests totales: \(totalRequests)")
    print("   ⚠️  Errores: \(errorCount)")
    print("")
    print("📋 Próximo paso:")
    print("   Copiar el archivo al bundle de la app:")
    print("   cp \(outputPath) 'Ars Medica Digitalis/Resources/icd11_mms_es.json'")
} catch {
    fatalError("❌ Error escribiendo JSON: \(error)")
}
