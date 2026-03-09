//
//  ScaleLoader.swift
//  Ars Medica Digitalis
//
//  Carga y decodificación de escalas clínicas desde JSON de Bundle.
//

import Foundation

enum ScaleLoaderError: Error, LocalizedError {
    case fileNotFound(name: String)
    case unreadableData(name: String)
    case decodingFailed(name: String, underlying: Error)
    case invalidScale(name: String, reason: String)
    case noScalesFound

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            "No se encontró el archivo de escala \(name).json en el bundle."
        case .unreadableData(let name):
            "No se pudo leer el archivo de escala \(name).json."
        case .decodingFailed(let name, let underlying):
            "No se pudo decodificar la escala \(name).json: \(underlying.localizedDescription)"
        case .invalidScale(let name, let reason):
            "La escala \(name).json no pasó la validación: \(reason)"
        case .noScalesFound:
            "No se encontraron escalas clínicas válidas en el bundle."
        }
    }
}

enum ScaleLoader {

    static func load(
        _ resourceName: String,
        bundle: Bundle = .main
    ) throws -> ClinicalScale {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw ScaleLoaderError.fileNotFound(name: resourceName)
        }

        guard let data = try? Data(contentsOf: url) else {
            throw ScaleLoaderError.unreadableData(name: resourceName)
        }

        do {
            let scale = try JSONDecoder().decode(ClinicalScale.self, from: data)
            try validate(scale, resourceName: resourceName)
            return scale
        } catch let loaderError as ScaleLoaderError {
            throw loaderError
        } catch {
            throw ScaleLoaderError.decodingFailed(name: resourceName, underlying: error)
        }
    }

    /// Carga todas las escalas válidas detectadas en los JSON del bundle.
    /// Se filtran archivos grandes para evitar procesar datasets no clínicos
    /// (por ejemplo catálogos masivos de medicamentos o CIE).
    static func loadAll(
        bundle: Bundle = .main,
        maximumFileSizeBytes: Int = 256_000
    ) throws -> [ClinicalScale] {
        let jsonURLs = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        var loadedScales: [ClinicalScale] = []

        for url in jsonURLs {
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard fileSize <= maximumFileSizeBytes else { continue }
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let scale = try? JSONDecoder().decode(ClinicalScale.self, from: data) else { continue }
            let resourceName = url.deletingPathExtension().lastPathComponent
            guard (try? validate(scale, resourceName: resourceName)) != nil else { continue }
            loadedScales.append(scale)
        }

        let deduplicated = Dictionary(grouping: loadedScales, by: \.id)
            .compactMap { _, values in values.first }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        guard !deduplicated.isEmpty else {
            throw ScaleLoaderError.noScalesFound
        }

        return deduplicated
    }

    private static func validate(_ scale: ClinicalScale, resourceName: String) throws {
        if scale.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ScaleLoaderError.invalidScale(name: resourceName, reason: "id vacío")
        }

        if scale.items.isEmpty {
            throw ScaleLoaderError.invalidScale(name: resourceName, reason: "sin preguntas")
        }

        if scale.scoring.ranges.isEmpty {
            throw ScaleLoaderError.invalidScale(name: resourceName, reason: "sin rangos de scoring")
        }

        let itemIDs = scale.items.map(\.id)
        if Set(itemIDs).count != itemIDs.count {
            throw ScaleLoaderError.invalidScale(name: resourceName, reason: "hay ítems con id repetido")
        }

        if let emptyOptionItem = scale.items.first(where: { $0.options.isEmpty }) {
            throw ScaleLoaderError.invalidScale(
                name: resourceName,
                reason: "el ítem \(emptyOptionItem.id) no tiene opciones"
            )
        }

        for item in scale.items {
            let optionIDs = item.options.map { $0.sourceID ?? $0.id.uuidString }
            if Set(optionIDs).count != optionIDs.count {
                throw ScaleLoaderError.invalidScale(
                    name: resourceName,
                    reason: "el ítem \(item.id) tiene opciones con id repetido"
                )
            }
        }

        if let meta = scale.meta {
            if meta.itemsCount != scale.items.count {
                throw ScaleLoaderError.invalidScale(
                    name: resourceName,
                    reason: "meta.itemsCount (\(meta.itemsCount)) no coincide con ítems (\(scale.items.count))"
                )
            }

            if meta.maxScore != scale.maximumScore {
                throw ScaleLoaderError.invalidScale(
                    name: resourceName,
                    reason: "meta.maxScore (\(meta.maxScore)) no coincide con maxScore calculado (\(scale.maximumScore))"
                )
            }
        }

        try validateScoringRanges(
            scale.scoring.ranges,
            expectedMinimum: scale.minimumScore,
            expectedMaximum: scale.maximumScore,
            resourceName: resourceName
        )
    }

    private static func validateScoringRanges(
        _ ranges: [ScoreRange],
        expectedMinimum: Int,
        expectedMaximum: Int,
        resourceName: String
    ) throws {
        let sortedRanges = ranges.sorted { lhs, rhs in
            if lhs.min == rhs.min { return lhs.max < rhs.max }
            return lhs.min < rhs.min
        }

        guard let firstRange = sortedRanges.first, let lastRange = sortedRanges.last else {
            throw ScaleLoaderError.invalidScale(name: resourceName, reason: "sin rangos de scoring")
        }

        if firstRange.min > expectedMinimum {
            throw ScaleLoaderError.invalidScale(
                name: resourceName,
                reason: "los rangos empiezan en \(firstRange.min), mayor al mínimo esperado \(expectedMinimum)"
            )
        }

        if lastRange.max < expectedMaximum {
            throw ScaleLoaderError.invalidScale(
                name: resourceName,
                reason: "los rangos terminan en \(lastRange.max), menor al máximo esperado \(expectedMaximum)"
            )
        }

        for range in sortedRanges {
            if range.min > range.max {
                throw ScaleLoaderError.invalidScale(
                    name: resourceName,
                    reason: "rango inválido \(range.min)-\(range.max)"
                )
            }
        }

        for (previous, current) in zip(sortedRanges, sortedRanges.dropFirst()) {
            if current.min <= previous.max {
                throw ScaleLoaderError.invalidScale(
                    name: resourceName,
                    reason: "rangos solapados entre \(previous.min)-\(previous.max) y \(current.min)-\(current.max)"
                )
            }

            if current.min > previous.max + 1 {
                throw ScaleLoaderError.invalidScale(
                    name: resourceName,
                    reason: "hay huecos entre rangos: \(previous.max) y \(current.min)"
                )
            }
        }
    }
}
