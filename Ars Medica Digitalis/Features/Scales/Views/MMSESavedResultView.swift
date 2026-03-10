//
//  MMSESavedResultView.swift
//  Ars Medica Digitalis
//
//  Detalle resumido de un resultado MMSE persistido.
//

import SwiftUI

struct MMSESavedResultView: View {
    let test: MMSETest
    let patientName: String
    let result: SavedScaleResultSnapshot

    private var interpretation: MMSEScoringRange? {
        test.scoring.interpretation(for: result.totalScore)
    }

    private var interpretationColor: Color {
        Color.clinicalRingColor(
            named: interpretation?.color ?? "",
            severity: interpretation?.severity ?? result.severity
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionGap) {
                scoreCard
                metadataCard
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Resultado guardado")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Card principal con score total e interpretación.
    private var scoreCard: some View {
        CardContainer(
            style: .flat,
            usesGlassEffect: false,
            backgroundStyle: .solid(interpretationColor.opacity(0.14))
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Puntaje MMSE")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(result.totalScore)/\(test.maximumScore)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(interpretation?.label ?? "Interpretación no disponible")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(interpretationColor)
            }
        }
    }

    /// Metadatos clínicos mínimos para trazabilidad temporal del resultado.
    private var metadataCard: some View {
        CardContainer(
            style: .flat,
            usesGlassEffect: false,
            backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                LabeledContent("Paciente", value: patientName)
                LabeledContent("Fecha", value: dateFormatter.string(from: result.date))
                LabeledContent("Severidad", value: result.severity.capitalized)
                LabeledContent("Respuestas registradas", value: "\(result.answers.count)")
            }
            .font(.body)
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

