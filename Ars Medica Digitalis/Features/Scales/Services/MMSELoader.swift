//
//  MMSELoader.swift
//  Ars Medica Digitalis
//
//  Servicio de carga y validación del JSON MMSE desde Bundle.
//

import Foundation

enum MMSELoaderError: Error, LocalizedError, Sendable {
    case fileNotFound(name: String)
    case unreadableData(name: String)
    case decodingFailed(name: String, underlying: String)
    case invalidTest(name: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            "No se encontró \(name).json en el bundle."
        case .unreadableData(let name):
            "No se pudo leer \(name).json."
        case .decodingFailed(let name, let underlying):
            "No se pudo decodificar \(name).json: \(underlying)"
        case .invalidTest(let name, let reason):
            "El JSON \(name).json es inválido: \(reason)"
        }
    }
}

/// Loader async y Sendable para desacoplar la vista de la lectura de archivos.
struct MMSELoader: Sendable {

    /// Carga el MMSE desde bundle y valida su integridad estructural.
    /// Se hace en async para no bloquear el hilo principal durante I/O y decode.
    func load(
        resourceName: String = "mmse",
        bundle: Bundle = .main
    ) async throws -> MMSETest {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw MMSELoaderError.fileNotFound(name: resourceName)
        }

        let data: Data
        do {
            // Se mueve la lectura de disco a un task detached para mantener UI fluida.
            data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
        } catch {
            throw MMSELoaderError.unreadableData(name: resourceName)
        }

        do {
            let decoder = JSONDecoder()

            // Compatibilidad con dos formatos: raíz directa o envelope {"test": ...}.
            if let wrapped = try? decoder.decode(MMSEEnvelope.self, from: data) {
                try validate(wrapped.test, resourceName: resourceName)
                return wrapped.test
            }

            let test = try decoder.decode(MMSETest.self, from: data)
            try validate(test, resourceName: resourceName)
            return test
        } catch let loaderError as MMSELoaderError {
            throw loaderError
        } catch {
            throw MMSELoaderError.decodingFailed(
                name: resourceName,
                underlying: error.localizedDescription
            )
        }
    }

    /// Validaciones mínimas para garantizar scoring y navegación consistentes.
    private func validate(_ test: MMSETest, resourceName: String) throws {
        guard !test.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MMSELoaderError.invalidTest(name: resourceName, reason: "id vacío")
        }

        guard !test.sections.isEmpty else {
            throw MMSELoaderError.invalidTest(name: resourceName, reason: "sin secciones")
        }

        guard !test.scoring.ranges.isEmpty else {
            throw MMSELoaderError.invalidTest(name: resourceName, reason: "sin rangos de scoring")
        }

        let sectionIDs = test.sections.map(\.id)
        guard Set(sectionIDs).count == sectionIDs.count else {
            throw MMSELoaderError.invalidTest(name: resourceName, reason: "hay secciones con id repetido")
        }

        let sectionItemIDs = test.sections.flatMap { section in
            section.items.map(\.id)
        }
        guard Set(sectionItemIDs).count == sectionItemIDs.count else {
            throw MMSELoaderError.invalidTest(name: resourceName, reason: "hay ítems con id repetido")
        }

        if test.sections.contains(where: { $0.items.isEmpty }) {
            throw MMSELoaderError.invalidTest(name: resourceName, reason: "existe una sección sin ítems")
        }

        if test.scorableItems.contains(where: { $0.effectiveMaxScore <= 0 }) {
            throw MMSELoaderError.invalidTest(name: resourceName, reason: "hay ítems evaluables con maxScore inválido")
        }

        if let expectedMaxScore = test.meta?.maxScore {
            let computedMaxScore = test.sections.reduce(0) { partialResult, section in
                partialResult + section.scorableItems.reduce(0) { $0 + $1.effectiveMaxScore }
            }

            guard expectedMaxScore == computedMaxScore else {
                throw MMSELoaderError.invalidTest(
                    name: resourceName,
                    reason: "meta.maxScore (\(expectedMaxScore)) no coincide con score calculado (\(computedMaxScore))"
                )
            }
        }

        try validateScoringRanges(test.scoring.ranges, resourceName: resourceName)
    }

    /// Verifica que los rangos sean válidos, no se solapen y estén ordenables.
    private func validateScoringRanges(
        _ ranges: [MMSEScoringRange],
        resourceName: String
    ) throws {
        let sorted = ranges.sorted { lhs, rhs in
            if lhs.min == rhs.min { return lhs.max < rhs.max }
            return lhs.min < rhs.min
        }

        for range in sorted where range.min > range.max {
            throw MMSELoaderError.invalidTest(
                name: resourceName,
                reason: "rango inválido \(range.min)-\(range.max)"
            )
        }

        for (previous, current) in zip(sorted, sorted.dropFirst()) where current.min <= previous.max {
            throw MMSELoaderError.invalidTest(
                name: resourceName,
                reason: "rangos solapados entre \(previous.min)-\(previous.max) y \(current.min)-\(current.max)"
            )
        }
    }
}

/// Envelope opcional para soportar JSON con clave raíz `test`.
private struct MMSEEnvelope: Decodable, Sendable {
    let test: MMSETest
}
