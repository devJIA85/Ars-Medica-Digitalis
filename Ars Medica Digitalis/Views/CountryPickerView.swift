//
//  CountryPickerView.swift
//  Ars Medica Digitalis
//
//  Picker de países buscable con secciones:
//  - Argentina fija al inicio
//  - Frecuentes (dinámicos según pacientes del profesional)
//  - Todos en orden alfabético
//

import SwiftUI

struct CountryPickerView: View {

    @Binding var selection: String
    let frequentCodes: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var pinnedItem: CountryItem? {
        CountryCatalog.item(for: CountryCatalog.pinnedCode)
    }

    private var frequentItems: [CountryItem] {
        frequentCodes.compactMap { CountryCatalog.item(for: $0) }
    }

    /// Países que no están en pinned ni en frecuentes
    private var remainingItems: [CountryItem] {
        let excludedCodes = Set([CountryCatalog.pinnedCode] + frequentCodes)
        return CountryCatalog.all.filter { !excludedCodes.contains($0.code) }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Resultados filtrados cuando se busca
    private var filteredItems: [CountryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return CountryCatalog.all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.code.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            if isSearching {
                searchResultsContent
            } else {
                sectionsContent
            }
        }
        .searchable(text: $searchText, prompt: "Buscar país")
    }

    // MARK: - Contenido por secciones (sin búsqueda)

    @ViewBuilder
    private var sectionsContent: some View {
        // Opción para limpiar selección
        Section {
            countryRow(code: "", label: "Sin especificar", flag: nil)
        }

        // Argentina fija
        if let pinned = pinnedItem {
            Section {
                countryRow(code: pinned.code, label: pinned.name, flag: pinned.flag)
            }
        }

        // Frecuentes dinámicos
        if !frequentItems.isEmpty {
            Section("Frecuentes") {
                ForEach(frequentItems) { country in
                    countryRow(code: country.code, label: country.name, flag: country.flag)
                }
            }
        }

        // Todos los demás en orden alfabético
        Section("Todos") {
            ForEach(remainingItems) { country in
                countryRow(code: country.code, label: country.name, flag: country.flag)
            }
        }
    }

    // MARK: - Resultados de búsqueda

    @ViewBuilder
    private var searchResultsContent: some View {
        if filteredItems.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ForEach(filteredItems) { country in
                countryRow(code: country.code, label: country.name, flag: country.flag)
            }
        }
    }

    // MARK: - Fila de país

    private func countryRow(code: String, label: String, flag: String?) -> some View {
        Button {
            selection = code
            dismiss()
        } label: {
            HStack {
                if let flag {
                    Text(flag)
                }
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if selection == code || isLegacyMatch(code) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    /// Compara con datos legacy: si la selección actual es un nombre completo
    /// que coincide con este código ISO, lo marca como seleccionado.
    private func isLegacyMatch(_ code: String) -> Bool {
        guard !code.isEmpty, selection.count > 2 else { return false }
        return CountryCatalog.resolveCode(selection) == code
    }
}
