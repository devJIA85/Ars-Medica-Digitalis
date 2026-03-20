//
//  ICD11SearchViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para la búsqueda de diagnósticos en la API CIE-11.
//  Gestiona el debounce de la consulta, el estado de carga y
//  los resultados para la vista ICD11SearchView.
//
//  Estrategia offline-first: muestra resultados locales de inmediato
//  y en paralelo intenta la API online. Si la API responde con
//  resultados rankeados, reemplaza los locales transparentemente.
//

import Foundation
import OSLog
import SwiftData

@Observable
final class ICD11SearchViewModel {

    private nonisolated let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "ICD11Search")

    // MARK: - Estado observable

    var results: [ICD11SearchResult] = []
    var isLoading: Bool = false
    var errorMessage: String?

    /// Indica que los resultados actuales provienen del catálogo offline
    var isOfflineMode: Bool = false

    // MARK: - Estado privado

    /// Tarea de búsqueda activa. Se cancela al iniciar una nueva
    /// para implementar debounce natural.
    private var searchTask: Task<Void, Never>?

    // MARK: - Búsqueda

    /// Ejecuta una búsqueda offline-first con debounce de 400ms.
    /// Muestra resultados locales instantáneamente y en paralelo
    /// intenta la API online para obtener resultados rankeados.
    func search(query: String, context: ModelContext) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 3 else {
            results = []
            errorMessage = nil
            isLoading = false
            isOfflineMode = false
            return
        }

        searchTask = Task {
            // Debounce: esperar 400ms antes de ejecutar.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            errorMessage = nil

            // Paso 1: resultados locales inmediatos
            let localResults = searchOffline(query: trimmed, context: context)
            if !localResults.isEmpty {
                results = localResults
                isOfflineMode = true
            } else {
                // Sin resultados locales — mostrar spinner mientras busca online
                isLoading = true
            }

            // Paso 2: intentar online en paralelo para mejorar resultados
            do {
                let onlineResults = try await ICD11Service.shared.search(query: trimmed)
                guard !Task.isCancelled else { return }
                if !onlineResults.isEmpty {
                    results = onlineResults
                    isOfflineMode = false
                    upsertOnlineResults(onlineResults, context: context)
                }
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("ICD11 online search failed: \(error)")
                if results.isEmpty {
                    errorMessage = error.localizedDescription
                }
            }

            isLoading = false
        }
    }

    // MARK: - Búsqueda Offline

    /// Busca en el catálogo local ICD11Entry usando #Predicate.
    /// Solo devuelve entidades con classKind "category" (las que tienen código asignable).
    @MainActor
    private func searchOffline(query: String, context: ModelContext) -> [ICD11SearchResult] {
        let predicate = #Predicate<ICD11Entry> { entry in
            entry.title.localizedStandardContains(query) && entry.classKind == "category"
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 25

        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.map { entry in
            ICD11SearchResult(
                id: entry.uri,
                theCode: entry.code,
                title: entry.title,
                chapter: entry.chapterCode.isEmpty ? nil : entry.chapterCode,
                score: nil
            )
        }
    }

    // MARK: - Persistencia Online

    @MainActor
    private func upsertOnlineResults(_ results: [ICD11SearchResult], context: ModelContext) {
        let candidates = results.compactMap { result -> ICD11SearchResult? in
            guard let code = result.theCode, !code.isEmpty else { return nil }
            return result
        }

        guard !candidates.isEmpty else { return }

        let candidateURIs = Set(candidates.map(\.id))
        let existingPredicate = #Predicate<ICD11Entry> { entry in
            candidateURIs.contains(entry.uri)
        }
        let existingDescriptor = FetchDescriptor(predicate: existingPredicate)
        let existingEntries = (try? context.fetch(existingDescriptor)) ?? []
        var existingByURI = Dictionary(uniqueKeysWithValues: existingEntries.map { ($0.uri, $0) })
        var didChange = false

        for result in candidates {
            if let existing = existingByURI[result.id] {
                let nextCode = result.theCode ?? existing.code
                let nextTitle = result.title
                let nextChapterCode = result.chapter ?? existing.chapterCode

                if existing.code != nextCode {
                    existing.code = nextCode
                    didChange = true
                }
                if existing.title != nextTitle {
                    existing.title = nextTitle
                    didChange = true
                }
                if existing.chapterCode != nextChapterCode {
                    existing.chapterCode = nextChapterCode
                    didChange = true
                }
                if existing.classKind.isEmpty {
                    existing.classKind = "category"
                    didChange = true
                }
            } else {
                let newEntry = ICD11Entry(
                    code: result.theCode ?? "",
                    title: result.title,
                    uri: result.id,
                    classKind: "category",
                    chapterCode: result.chapter ?? ""
                )
                context.insert(newEntry)
                existingByURI[result.id] = newEntry
                didChange = true
            }
        }

        if didChange {
            try? context.save()
        }
    }
}
