//
//  ClinicalMetricTile.swift
//  Ars Medica Digitalis
//
//  Tile y grilla compacta de métricas clínicas para insights del dashboard.
//

import SwiftUI

struct ClinicalMetricTile: View {

    let metric: InsightMetric

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: metric.systemImage)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(metric.tone.color)

            Text(metric.value)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.primary)

            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .topLeading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibilityLabel)
        .onAppear {
            guard isVisible == false else { return }
            withAnimation(.easeOut(duration: 0.2).delay(metric.animationDelay)) {
                isVisible = true
            }
        }
    }
}

struct ClinicalMetricsGrid: View {

    let metrics: [InsightMetric]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: 12)]
        } else {
            [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(metrics) { metric in
                ClinicalMetricTile(metric: metric)
            }
        }
    }
}
