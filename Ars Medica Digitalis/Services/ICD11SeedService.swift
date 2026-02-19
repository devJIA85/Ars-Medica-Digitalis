//
//  ICD11SeedService.swift
//  Ars Medica Digitalis
//
//  Servicio que pobla el catálogo offline de CIE-11 en SwiftData
//  a partir del JSON semilla incluido en el bundle de la app.
//  Se ejecuta una sola vez en el primer launch de la app.
//
//  Usa @ModelActor para insertar ~36.000 registros en background
//  sin bloquear el main thread.
//

import Foundation
import SwiftData

@ModelActor
actor ICD11SeedService {

    // MARK: - DTO para decodificar el JSON semilla

    private struct SeedEntry: Decodable {
        let code: String
        let title: String
        let uri: String
        let classKind: String
        let chapterCode: String
    }

    // MARK: - Seed

    /// Pobla el catálogo CIE-11 si la tabla está vacía.
    /// Lee el JSON del bundle e inserta registros en lotes de 1.000
    /// para controlar el uso de memoria.
    func seedIfNeeded() async {
        let descriptor = FetchDescriptor<ICD11Entry>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0

        // Si ya hay datos, no hacer nada
        guard count == 0 else { return }

        guard let url = Bundle.main.url(forResource: "icd11_mms_es", withExtension: "json") else {
            // El JSON semilla aún no fue generado — no es un error fatal,
            // simplemente la búsqueda offline no estará disponible.
            return
        }

        guard let data = try? Data(contentsOf: url) else { return }

        guard let entries = try? JSONDecoder().decode([SeedEntry].self, from: data) else {
            return
        }

        // Insertar en lotes para no consumir excesiva memoria
        let batchSize = 1000
        for (index, entry) in entries.enumerated() {
            let record = ICD11Entry(
                code: entry.code,
                title: entry.title,
                uri: entry.uri,
                classKind: entry.classKind,
                chapterCode: entry.chapterCode
            )
            modelContext.insert(record)

            // Guardar cada lote para liberar memoria
            if (index + 1) % batchSize == 0 {
                try? modelContext.save()
            }
        }

        // Guardar remanente
        try? modelContext.save()
    }
}
