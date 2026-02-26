//
//  MedicationSeedService.swift
//  Ars Medica Digitalis
//
//  Servicio que pobla el vademécum local en SwiftData
//  desde un CSV incluido en el bundle.
//

import Foundation
import SwiftData

@ModelActor
actor MedicationSeedService {

    func seedIfNeeded() async {
        let seededPredicate = #Predicate<Medication> { medication in
            medication.isUserCreated == false
        }
        let descriptor = FetchDescriptor<Medication>(predicate: seededPredicate)
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0

        // Si ya existe semilla del vademecum, no reseedear.
        guard count == 0 else { return }

        guard let url = Bundle.main.url(forResource: "vademecum_swiftdata_ready", withExtension: "csv") else {
            return
        }

        guard let rows = parseCSVRows(from: url), rows.count > 1 else { return }

        let header = rows[0].map { normalizeHeader($0) }
        guard let indexMap = buildIndexMap(header: header) else { return }

        var seenKeys = Set<String>()
        let batchSize = 500
        var inserted = 0

        for row in rows.dropFirst() {
            guard row.count >= header.count else { continue }

            let principioActivo = normalizeValue(row[safe: indexMap.principioActivo] ?? "")
            let nombreComercial = normalizeValue(row[safe: indexMap.nombreComercial] ?? "")
            let potencia = normalizeValue(row[safe: indexMap.potencia] ?? "")
            let potenciaValor = normalizeValue(row[safe: indexMap.potenciaValor] ?? "")
            let potenciaUnidad = normalizeValue(row[safe: indexMap.potenciaUnidad] ?? "")
            let contenido = normalizeValue(row[safe: indexMap.contenido] ?? "")
            let presentacion = normalizeValue(row[safe: indexMap.presentacion] ?? "")
            let laboratorio = normalizeValue(row[safe: indexMap.laboratorio] ?? "")

            // Evitar duplicados exactos en la semilla.
            let key = [
                principioActivo.lowercased(),
                nombreComercial.lowercased(),
                potencia.lowercased(),
                potenciaValor.lowercased(),
                potenciaUnidad.lowercased(),
                contenido.lowercased(),
                presentacion.lowercased(),
                laboratorio.lowercased(),
            ].joined(separator: "|")

            guard !key.replacingOccurrences(of: "|", with: "").isEmpty else { continue }
            guard seenKeys.insert(key).inserted else { continue }

            let medication = Medication(
                principioActivo: principioActivo,
                nombreComercial: nombreComercial,
                potencia: potencia,
                potenciaValor: potenciaValor,
                potenciaUnidad: potenciaUnidad,
                contenido: contenido,
                presentacion: presentacion,
                laboratorio: laboratorio,
                isUserCreated: false
            )

            modelContext.insert(medication)
            inserted += 1

            if inserted % batchSize == 0 {
                try? modelContext.save()
            }
        }

        try? modelContext.save()
    }

    // MARK: - CSV parsing

    private func parseCSVRows(from url: URL) -> [[String]]? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Fallback latin1 por compatibilidad de acentos si el CSV no está en UTF-8.
        let content = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)

        guard let content else { return nil }
        return parseCSVRows(from: content)
    }

    private func parseCSVRows(from content: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false

        var index = content.startIndex
        while index < content.endIndex {
            let char = content[index]

            if char == "\"" {
                let nextIndex = content.index(after: index)
                if isInsideQuotes, nextIndex < content.endIndex, content[nextIndex] == "\"" {
                    // Escape de comilla doble dentro de campo entrecomillado.
                    field.append("\"")
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if char == ",", !isInsideQuotes {
                row.append(field)
                field = ""
            } else if char == "\n", !isInsideQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if char == "\r", !isInsideQuotes {
                // Ignorar CR (soporte CRLF)
            } else {
                field.append(char)
            }

            index = content.index(after: index)
        }

        // Flush final
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    // MARK: - Header mapping

    private typealias ColumnIndexMap = (
        principioActivo: Int,
        nombreComercial: Int,
        potencia: Int,
        potenciaValor: Int,
        potenciaUnidad: Int,
        contenido: Int,
        presentacion: Int,
        laboratorio: Int
    )

    private func buildIndexMap(header: [String]) -> ColumnIndexMap? {
        guard
            let principioActivo = header.firstIndex(of: "principio_activo"),
            let nombreComercial = header.firstIndex(of: "nombre_comercial"),
            let potencia = header.firstIndex(of: "potencia"),
            let potenciaValor = header.firstIndex(of: "potencia_valor"),
            let potenciaUnidad = header.firstIndex(of: "potencia_unidad"),
            let contenido = header.firstIndex(of: "contenido"),
            let presentacion = header.firstIndex(of: "presentacion"),
            let laboratorio = header.firstIndex(of: "laboratorio")
        else {
            return nil
        }

        return (
            principioActivo,
            nombreComercial,
            potencia,
            potenciaValor,
            potenciaUnidad,
            contenido,
            presentacion,
            laboratorio
        )
    }

    private func normalizeHeader(_ value: String) -> String {
        normalizeAccents(value)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeValue(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "" }

        let lowered = cleaned.lowercased()
        if lowered == "nan" || lowered == "null" || lowered == "nil" {
            return ""
        }

        return cleaned
    }

    private func normalizeAccents(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
