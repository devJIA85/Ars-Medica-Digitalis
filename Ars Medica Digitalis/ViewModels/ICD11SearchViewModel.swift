//
//  ICD11SearchViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para la búsqueda de diagnósticos en la API CIE-11.
//  Gestiona el debounce de la consulta, el estado de carga y
//  los resultados para la vista ICD11SearchView.
//
//  Estrategia híbrida: intenta búsqueda online primero (resultados
//  rankeados por relevancia), y si falla usa el catálogo offline
//  local (ICD11Entry en SwiftData) como fallback automático.
//

import Foundation
import SwiftData

@Observable
final class ICD11SearchViewModel {

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

    /// Ejecuta una búsqueda con debounce de 400ms.
    /// Cada invocación cancela la búsqueda anterior, evitando
    /// llamadas redundantes mientras el usuario escribe.
    ///
    /// Si la búsqueda online falla (sin conexión, error de red),
    /// busca automáticamente en el catálogo offline local.
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
            // Si la Task se cancela durante la espera, no se llama a la API.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            isLoading = true
            errorMessage = nil
            isOfflineMode = false

            do {
                let searchResults = try await ICD11Service.shared.search(query: trimmed)
                guard !Task.isCancelled else { return }
                results = searchResults
            } catch {
                guard !Task.isCancelled else { return }

                // Fallback: búsqueda en catálogo offline local
                let localResults = searchOffline(query: trimmed, context: context)
                if !localResults.isEmpty {
                    results = localResults
                    isOfflineMode = true
                } else {
                    errorMessage = error.localizedDescription
                }
            }

            isLoading = false
        }
    }

    // MARK: - Búsqueda Offline

    /// Busca en el catálogo local ICD11Entry usando #Predicate.
    /// Solo devuelve entidades con classKind "category" (las que tienen código asignable).
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
                chapter: nil,
                score: nil
            )
        }
    }
}
