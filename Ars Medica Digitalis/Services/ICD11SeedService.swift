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

    /// Pobla el catálogo CIE-11 si la tabla está vacía o incompleta.
    /// Lee el JSON del bundle e inserta registros en lotes de 1.000
    /// para controlar el uso de memoria.
    ///
    /// ## Detección de seed parcial
    /// Compara el recuento existente con el total del JSON.
    /// Si difieren (seed interrumpido en un lanzamiento anterior), elimina
    /// todos los registros existentes antes de reintentar desde cero para
    /// evitar duplicados o catálogo inconsistente.
    ///
    /// ## Manejo de errores
    /// Si falla un save intermedio o el save final, elimina todo lo insertado
    /// hasta ese punto y abandona. El próximo lanzamiento reintentará.
    func seedIfNeeded() async {
        guard let url = Bundle.main.url(forResource: "icd11_mms_es", withExtension: "json") else {
            // El JSON semilla aún no fue generado — no es un error fatal,
            // simplemente la búsqueda offline no estará disponible.
            return
        }

        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SeedEntry].self, from: data),
              entries.isEmpty == false else {
            return
        }

        let descriptor = FetchDescriptor<ICD11Entry>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0

        // Seed completo: nada que hacer
        if existingCount == entries.count { return }

        // Seed parcial de un lanzamiento anterior: limpiar antes de reintentar
        if existingCount > 0 {
            do {
                try modelContext.delete(model: ICD11Entry.self)
                try modelContext.save()
            } catch {
                // Si no podemos limpiar el estado parcial, no seguir:
                // un seed sobre datos corruptos podría generar duplicados.
                return
            }
        }

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

            if (index + 1) % batchSize == 0 {
                do {
                    try modelContext.save()
                } catch {
                    // Fallo en lote intermedio: revertir todo y abandonar.
                    // El próximo lanzamiento detectará el estado parcial y reintentará.
                    try? modelContext.delete(model: ICD11Entry.self)
                    try? modelContext.save()
                    return
                }
            }
        }

        // Save del lote remanente
        do {
            try modelContext.save()
        } catch {
            // Fallo en save final: revertir para forzar reintento limpio.
            try? modelContext.delete(model: ICD11Entry.self)
            try? modelContext.save()
        }
    }
}
