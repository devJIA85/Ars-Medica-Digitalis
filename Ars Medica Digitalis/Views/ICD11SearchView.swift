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
import SwiftData

struct ICD11SearchView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel = ICD11SearchViewModel()

    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool

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
        .searchable(
            text: $searchText,
            placement: .automatic,
            prompt: "Ej: depresión, fractura, diabetes..."
        )
        .searchToolbarBehavior(.minimize)
        .modifier(SearchFieldAutoFocusModifier(isSearchFieldFocused: $isSearchFieldFocused))
        .onAppear {
            if #available(iOS 18.0, *) {
                isSearchFieldFocused = true
            }
        }
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
        let chapterColor = icd11ChapterColor(for: result.chapter)
        let relevance = relevanceBadge(for: result.score)

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .foregroundStyle(titleColor(for: result.chapter))

                HStack(spacing: 6) {
                    if let code = result.theCode, !code.isEmpty {
                        ICD11ChipView(text: code, color: chapterColor, emphasis: .high)
                    }

                    if let chapter = result.chapter, !chapter.isEmpty {
                        ICD11ChipView(text: icd11ChapterName(for: chapter), color: chapterColor, emphasis: .low)
                    }

                    if let relevance {
                        ICD11ChipView(text: relevance.label, color: relevance.color, emphasis: .low)
                    }
                }
            }

            Spacer()

            if isAlreadySelected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
            }
        }
        .contentShape(Rectangle())
    }

    private func titleColor(for chapter: String?) -> Color {
        guard let chapter, !chapter.isEmpty else { return .primary }
        let base = icd11ChapterColor(for: chapter)
        return base.opacity(colorScheme == .dark ? 0.95 : 0.9)
    }

    private func relevanceBadge(for score: Double?) -> (label: String, color: Color)? {
        guard let score else { return nil }

        if score >= 0.8 {
            return ("Alta relevancia", .green)
        } else if score >= 0.5 {
            return ("Relevancia media", .orange)
        } else {
            return ("Relevancia baja", .gray)
        }
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

private struct SearchFieldAutoFocusModifier: ViewModifier {
    let isSearchFieldFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.searchFocused(isSearchFieldFocused)
        } else {
            content
        }
    }
}

#Preview {
    NavigationStack {
        ICD11SearchView(
            alreadySelected: [],
            onSelect: { _ in }
        )
    }
}
