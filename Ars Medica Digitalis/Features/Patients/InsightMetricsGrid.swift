//
//  InsightMetricsGrid.swift
//  Ars Medica Digitalis
//
//  Grid 2x2 de métricas clínicas del dashboard.
//

import SwiftUI

struct InsightMetricsGrid: View {

    let metrics: [InsightMetric]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: AppSpacing.md)]
        } else {
            [
                GridItem(.flexible(), spacing: AppSpacing.md),
                GridItem(.flexible(), spacing: AppSpacing.md),
            ]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.md) {
            ForEach(metrics) { metric in
                InsightMetricCard(metric: metric)
            }
        }
    }
}
