#!/usr/bin/env swift
import Foundation

// ===============================
// CONFIG
// ===============================

let releaseVersion = "2024-01"
let language = "es"

// Base URL por parámetro (Docker)
var baseURL = "http://localhost"
if CommandLine.arguments.contains("--base-url"),
   let idx = CommandLine.arguments.firstIndex(of: "--base-url"),
   idx + 1 < CommandLine.arguments.count {
    baseURL = CommandLine.arguments[idx + 1]
}

let mmsRootURL = "\(baseURL)/icd/release/11/\(releaseVersion)/mms"

print("🚀 ICD-11 Seeder (Docker mode)")
print("🌐 Base URL:", baseURL)
print("")

// ===============================
// MODELO
// ===============================

struct SeedEntry: Codable {
    let code: String
    let title: String
    let uri: String
    let classKind: String
    let chapterCode: String
}

// ===============================
// ESTADO
// ===============================

var visitedURIs = Set<String>()
var allEntries: [SeedEntry] = []
var totalRequests = 0

// ===============================
// HTTP SIMPLE
// ===============================

func httpGet(_ urlString: String) -> [String: Any]? {
    guard let url = URL(string: urlString) else { return nil }

    var request = URLRequest(url: url)
    request.setValue("v2", forHTTPHeaderField: "API-Version")
    request.setValue(language, forHTTPHeaderField: "Accept-Language")

    let sem = DispatchSemaphore(value: 0)
    var result: [String: Any]?

    URLSession.shared.dataTask(with: request) { data, _, _ in
        defer { sem.signal() }
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        result = json
    }.resume()

    sem.wait()
    totalRequests += 1
    return result
}

// ===============================
// LIMPIEZA
// ===============================

func cleanHTML(_ text: String) -> String {
    var result = text
    let regex = try? NSRegularExpression(pattern: "<[^>]+>")
    if let regex {
        result = regex.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: ""
        )
    }
    return result
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// ===============================
// NORMALIZADOR URL OMS → DOCKER
// ===============================

func normalize(_ uri: String) -> String {
    uri
        .replacingOccurrences(of: "https://id.who.int", with: baseURL)
        .replacingOccurrences(of: "http://id.who.int", with: baseURL)
}

// ===============================
// TRAVERSAL
// ===============================

func traverse(uri: String, chapterCode: String) {

    if visitedURIs.contains(uri) { return }
    visitedURIs.insert(uri)

    let resolved = normalize(uri)

    guard let json = httpGet(resolved) else {
        print("⚠️ No se pudo obtener:", resolved)
        return
    }

    let classKind = json["classKind"] as? String ?? ""

    var title = ""
    if let dict = json["title"] as? [String: Any] {
        title = dict["@value"] as? String ?? ""
    } else if let str = json["title"] as? String {
        title = str
    }

    let code =
        json["code"] as? String ??
        json["codeRange"] as? String ??
        json["blockId"] as? String ?? ""

    let currentChapter =
        classKind == "chapter" ? code : chapterCode

    if !title.isEmpty {
        allEntries.append(
            SeedEntry(
                code: code,
                title: cleanHTML(title),
                uri: json["@id"] as? String ?? uri,
                classKind: classKind,
                chapterCode: currentChapter
            )
        )
    }

    if allEntries.count % 500 == 0 {
        print("📊 \(allEntries.count) entradas — \(totalRequests) requests")
    }

    if let children = json["child"] as? [String] {
        for child in children {
            traverse(uri: child, chapterCode: currentChapter)
        }
    }
}

// ===============================
// MAIN
// ===============================

print("📥 Obteniendo capítulos raíz...")

guard let root = httpGet(mmsRootURL),
      let chapters = root["child"] as? [String] else {
    fatalError("❌ No se pudieron obtener capítulos")
}

print("📋 Capítulos encontrados:", chapters.count)
print("")

for (i, chapter) in chapters.enumerated() {
    print("📖 Capítulo \(i+1)/\(chapters.count)")
    traverse(uri: chapter, chapterCode: "")
    print("   ✅ Total:", allEntries.count)
}

print("")
print("💾 Guardando JSON...")

let output = "Scripts/icd11_mms_es.json"
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted]

let data = try encoder.encode(allEntries)
try data.write(to: URL(fileURLWithPath: output))

print("")
print("✅ COMPLETADO")
print("📄 Archivo:", output)
print("📊 Entradas:", allEntries.count)
print("📦 Tamaño:", String(format: "%.2f MB", Double(data.count) / 1_000_000))
print("🌐 Requests:", totalRequests)
