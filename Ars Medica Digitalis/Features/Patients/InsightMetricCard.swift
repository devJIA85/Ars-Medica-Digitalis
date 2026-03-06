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
    let isCompact: Bool

    @State private var isVisible = false

    init(metric: InsightMetric, isCompact: Bool = false) {
        self.metric = metric
        self.isCompact = isCompact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : AppSpacing.sm) {
            Image(systemName: metric.systemImage)
                .font((isCompact ? Font.headline : Font.title3).weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(metric.tone.color)
                .frame(width: isCompact ? 30 : 36, height: isCompact ? 30 : 36)
                .background(metric.tone.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(metric.value)
                .font(.system(size: isCompact ? 28 : 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(.primary)

            Text(metric.title)
                .font((isCompact ? Font.subheadline : Font.headline).weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(metric.description)
                .font(.footnote)
                .lineLimit(isCompact ? 1 : 2)
                .foregroundStyle(.secondary)
        }
        .padding(isCompact ? 12 : AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: isCompact ? 132 : 168, alignment: .topLeading)
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
