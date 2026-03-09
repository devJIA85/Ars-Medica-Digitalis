//
//  ScaleResultView.swift
//  Ars Medica Digitalis
//
//  Resultado clínico e interpretación final de una escala aplicada.
//

import SwiftUI
import SwiftData

struct ScaleResultView: View {

    @Environment(\.modelContext) private var modelContext

    let viewModel: ScaleSessionViewModel
    let onSessionSaved: () -> Void

    init(
        viewModel: ScaleSessionViewModel,
        onSessionSaved: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onSessionSaved = onSessionSaved
    }

    @State private var didSaveResult: Bool = false
    @State private var saveErrorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionGap) {
                if let result = viewModel.computedResult {
                    resultCard(result: result)
                    saveButton
                } else {
                    ContentUnavailableView(
                        "Resultado no disponible",
                        systemImage: "exclamationmark.triangle",
                        description: Text("No se encontró un score calculado para esta sesión.")
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .themedBackground()
        .navigationTitle("Resultado")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "No se pudo guardar",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { isPresented in
                    if isPresented == false { saveErrorMessage = nil }
                }
            )
        ) {
            Button("Aceptar", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Intentá nuevamente.")
        }
    }

    private func resultCard(result: ScaleComputedResult) -> some View {
        CardContainer(style: .elevated) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Score: \(result.totalScore) / \(result.maximumScore)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(result.interpretationLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(scaleColor(for: result))

                Text("Severidad: \(result.severity)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Este resultado no constituye diagnóstico clínico.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCardEntrance()
    }

    private var saveButton: some View {
        Button {
            saveResult()
        } label: {
            Text(didSaveResult ? "Resultado guardado" : "Guardar resultado")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(didSaveResult)
        .accessibilityLabel(didSaveResult ? "Resultado guardado" : "Guardar resultado")
    }

    private func saveResult() {
        do {
            _ = try viewModel.saveResult(in: modelContext)
            didSaveResult = true
            onSessionSaved()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func scaleColor(for result: ScaleComputedResult) -> Color {
        Color.scaleResultColor(named: result.color, severity: result.severity)
    }
}

private extension Color {
    static func scaleResultColor(named colorName: String, severity: String) -> Color {
        switch colorName.lowercased() {
        case "green": .green
        case "yellow": .yellow
        case "orange": .orange
        case "red": .red
        case "blue": .blue
        case "purple": .purple
        case "teal": .teal
        default:
            switch severity.lowercased() {
            case "minimal": .green
            case "mild": .yellow
            case "moderate": .orange
            case "severe": .red
            default: .secondary
            }
        }
    }
}
