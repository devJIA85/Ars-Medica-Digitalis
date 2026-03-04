//
//  ClinicalMetric.swift
//  Ars Medica Digitalis
//
//  Primitiva reutilizable para métricas clínicas del dashboard.
//

import SwiftUI

struct ClinicalMetric: View {

    enum Style {
        case material
        case subtle

        fileprivate var fillStyle: AnyShapeStyle {
            switch self {
            case .material:
                return AnyShapeStyle(.ultraThinMaterial)
            case .subtle:
                return AnyShapeStyle(.quaternary.opacity(0.55))
            }
        }
    }

    let title: String
    let value: String
    var style: Style = .subtle

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(AppSpacing.md)
        .background(style.fillStyle, in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
