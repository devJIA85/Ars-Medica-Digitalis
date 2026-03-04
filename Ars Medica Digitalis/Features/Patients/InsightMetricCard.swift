//
//  InsightMetricCard.swift
//  Ars Medica Digitalis
//
//  Card de métrica clínica para el dashboard de pacientes.
//

import SwiftUI

enum InsightMetricTone: String, Equatable, Sendable {
    case critical
    case warning
    case positive
    case informational

    var color: Color {
        switch self {
        case .critical:
            .red
        case .warning:
            .orange
        case .positive:
            .green
        case .informational:
            .blue
        }
    }
}

struct InsightMetric: Identifiable, Equatable, Sendable {
    let id: String
    let value: String
    let title: String
    let description: String
    let systemImage: String
    let tone: InsightMetricTone
    let accessibilityLabel: String
    let animationDelay: Double
}

struct InsightMetricCard: View {

    let metric: InsightMetric

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Image(systemName: metric.systemImage)
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(metric.tone.color)
                .frame(width: 36, height: 36)
                .background(metric.tone.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(metric.value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(.primary)

            Text(metric.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(metric.description)
                .font(.footnote)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .strokeBorder(metric.tone.color.opacity(0.20), lineWidth: 1)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibilityLabel)
        .onAppear {
            guard isVisible == false else { return }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82).delay(metric.animationDelay)) {
                isVisible = true
            }
        }
    }
}
