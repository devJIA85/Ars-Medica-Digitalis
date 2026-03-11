//
//  MMSEScoreView.swift
//  Ars Medica Digitalis
//
//  Resultado final MMSE con interpretación clínica basada en rangos JSON.
//

import SwiftUI

struct MMSEScoreView: View {
    let test: MMSETest
    let totalScore: Int
    let sectionScores: [String: Int]
    let interpretation: MMSEScoringRange?

    @State private var showResult: Bool = false

    private var interpretationColor: Color {
        Color.clinicalRingColor(
            named: interpretation?.color ?? "",
            severity: interpretation?.severity ?? ""
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Resultado final")
                .font(.headline)
                .foregroundStyle(.primary)

            resultCard
                .keyframeAnimator(
                    initialValue: MMSEAnimationValues(),
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

            sectionScoresCard

            rangesCard
        }
    }

    /// Card principal con score total e interpretación activa.
    /// El color se deriva del JSON para no acoplar severidades en código.
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Puntaje MMSE")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(totalScore)/\(test.maximumScore)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .monospacedDigit()

            Text(interpretation?.label ?? "Sin interpretación disponible")
                .font(.body.weight(.semibold))
                .foregroundStyle(interpretationColor)

            if let interpretation {
                Text("Rango \(interpretation.min)–\(interpretation.max)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(interpretationColor.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .stroke(interpretationColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// Desglose por sección para feedback clínico fino.
    private var sectionScoresCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Puntajes por sección")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            ForEach(Array(test.sections.enumerated()), id: \.element.id) { index, section in
                HStack {
                    Text(section.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(sectionScores[section.id, default: 0])/\(section.maxScore)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }

                if index < test.sections.count - 1 {
                    Divider()
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    /// Tabla de rangos tomada del JSON para transparencia de interpretación.
    private var rangesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Rangos de interpretación")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            ForEach(test.scoring.ranges.sorted(by: { $0.min > $1.min })) { range in
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(Color.clinicalRingColor(named: range.color, severity: range.severity))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    Text("\(range.min)–\(range.max)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(range.label)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

private struct MMSEAnimationValues {
    var scale: CGFloat = 0.92
    var opacity: Double = 0
}
