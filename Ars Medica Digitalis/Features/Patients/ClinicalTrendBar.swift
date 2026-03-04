//
//  ClinicalTrendBar.swift
//  Ars Medica Digitalis
//
//  Barra horizontal de tendencias clínicas estilo dashboard.
//

import SwiftUI

struct ClinicalTrendBar: View {

    let trends: [ClinicalTrend]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(trends) { trend in
                    HStack(spacing: 6) {
                        Image(systemName: trend.systemImage)
                            .font(.caption.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(trendColor(for: trend.tone))

                        Text(trend.displayLabel)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(trendColor(for: trend.tone).opacity(0.18), lineWidth: 1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(trend.accessibilityLabel)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func trendColor(for tone: ClinicalTrendTone) -> Color {
        switch tone {
        case .positive:
            .green
        case .caution:
            .orange
        case .neutral:
            .secondary
        }
    }
}
