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
    @Environment(\.scaleFlowCoordinator) private var coordinator

    let viewModel: ScaleSessionViewModel

    @State private var didSaveResult: Bool = false
    @State private var saveErrorMessage: String? = nil
    @State private var showResult: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionGap) {
                if let result = viewModel.computedResult {
                    resultCard(result: result)
                        .keyframeAnimator(
                            initialValue: ResultAnimationValues(),
                            trigger: showResult
                        ) { content, value in
                            content
                                .scaleEffect(value.scale)
                                .opacity(value.opacity)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                SpringKeyframe(1.06, duration: 0.25, spring: .bouncy)
                                SpringKeyframe(1.0, duration: 0.3, spring: .smooth)
                            }
                            KeyframeTrack(\.opacity) {
                                LinearKeyframe(1.0, duration: 0.2)
                            }
                        }
                        .onAppear { showResult = true }
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
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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
        VStack(spacing: AppSpacing.xl) {
            // Score ring + interpretation
            VStack(spacing: AppSpacing.lg) {
                ClinicalScoreRing(
                    score: result.totalScore,
                    maxScore: result.maximumScore,
                    ranges: viewModel.scale.scoring.ranges,
                    colorName: result.color,
                    severity: result.severity
                )

                Text(result.interpretationLabel)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(severityColor(for: result))
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Score \(result.totalScore) de \(result.maximumScore)")
            .accessibilityValue(result.interpretationLabel)

            // Details card
            VStack(spacing: AppSpacing.md) {
                LabeledContent("Severidad", value: result.severity.capitalized)
                LabeledContent("Escala", value: result.scaleID)
            }
            .font(.body)
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous))

            // Disclaimer
            Text("Este resultado no constituye diagnóstico clínico.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            // El coordinador señala a ScalesListView que cierre el fullScreenCover.
            // Reemplaza el chain de callbacks onSessionSaved a través de 4 niveles.
            coordinator?.complete()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func severityColor(for result: ScaleComputedResult) -> Color {
        Color.clinicalRingColor(named: result.color, severity: result.severity)
    }
}

private struct ResultAnimationValues {
    var scale: CGFloat = 0.92
    var opacity: Double = 0
}
