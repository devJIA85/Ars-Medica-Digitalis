//
//  ICD11SearchViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para la búsqueda de diagnósticos en la API CIE-11.
//  Gestiona el debounce de la consulta, el estado de carga y
//  los resultados para la vista ICD11SearchView.
//

import Foundation

@Observable
final class ICD11SearchViewModel {

    // MARK: - Estado observable

    var results: [ICD11SearchResult] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Estado privado

    /// Tarea de búsqueda activa. Se cancela al iniciar una nueva
    /// para implementar debounce natural.
    private var searchTask: Task<Void, Never>?

    // MARK: - Búsqueda

    /// Ejecuta una búsqueda con debounce de 400ms.
    /// Cada invocación cancela la búsqueda anterior, evitando
    /// llamadas redundantes mientras el usuario escribe.
    func search(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 3 else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }

        searchTask = Task {
            // Debounce: esperar 400ms antes de ejecutar.
            // Si la Task se cancela durante la espera, no se llama a la API.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            isLoading = true
            errorMessage = nil

            do {
                let searchResults = try await ICD11Service.shared.search(query: trimmed)
                guard !Task.isCancelled else { return }
                results = searchResults
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}
