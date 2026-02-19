//
//  ICD11SearchView.swift
//  Ars Medica Digitalis
//
//  Vista de búsqueda de diagnósticos CIE-11 (HU-04).
//  Permite buscar, seleccionar y confirmar un diagnóstico
//  que se vinculará a la sesión clínica actual.
//
//  Búsqueda híbrida: online vía API WHO con fallback automático
//  al catálogo offline local (ICD11Entry en SwiftData).
//

import SwiftUI

struct ICD11SearchView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var viewModel = ICD11SearchViewModel()

    @State private var searchText: String = ""

    /// Diagnósticos ya seleccionados previamente (para mostrar checkmarks)
    let alreadySelected: [ICD11SearchResult]

    /// Callback cuando el usuario confirma una selección
    let onSelect: (ICD11SearchResult) -> Void

    var body: some View {
        List {
            // Badge de modo offline
            if viewModel.isOfflineMode {
                offlineBadge
            }

            if let error = viewModel.errorMessage {
                errorSection(message: error)
            } else if viewModel.isLoading {
                loadingSection
            } else if viewModel.results.isEmpty && searchText.count >= 3 {
                ContentUnavailableView(
                    "Sin resultados",
                    systemImage: "magnifyingglass",
                    description: Text("No se encontraron diagnósticos para esta búsqueda.")
                )
            } else if !viewModel.results.isEmpty {
                resultsSection
            }
        }
        .navigationTitle("Buscar CIE-11")
        .searchable(text: $searchText, prompt: "Ej: depresión, fractura, diabetes...")
        .onChange(of: searchText) { _, newValue in
            viewModel.search(query: newValue, context: modelContext)
        }
    }

    // MARK: - Badge Offline

    @ViewBuilder
    private var offlineBadge: some View {
        Section {
            Label("Modo offline — resultados del catálogo local", systemImage: "internaldrive")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Resultados

    @ViewBuilder
    private var resultsSection: some View {
        Section("Resultados (\(viewModel.results.count))") {
            ForEach(viewModel.results) { result in
                Button {
                    onSelect(result)
                    dismiss()
                } label: {
                    diagnosisRow(result)
                }
            }
        }
    }

    @ViewBuilder
    private func diagnosisRow(_ result: ICD11SearchResult) -> some View {
        let isAlreadySelected = alreadySelected.contains { $0.id == result.id }

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .foregroundStyle(.primary)

                if let code = result.theCode {
                    Text(code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isAlreadySelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Error

    @ViewBuilder
    private func errorSection(message: String) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("Error de conexión")
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.search(query: searchText, context: modelContext)
                } label: {
                    Label("Reintentar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView("Buscando diagnósticos...")
                Spacer()
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    NavigationStack {
        ICD11SearchView(
            alreadySelected: [],
            onSelect: { result in
                print("Seleccionado: \(result.title)")
            }
        )
    }
}
