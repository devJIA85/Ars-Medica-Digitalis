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

    enum Density {
        case regular
        case compact

        fileprivate var titleFont: Font {
            switch self {
            case .regular:
                return .caption
            case .compact:
                return .caption2
            }
        }

        fileprivate var valueFont: Font {
            switch self {
            case .regular:
                return .body.weight(.semibold)
            case .compact:
                return .callout.weight(.semibold)
            }
        }

        fileprivate var minHeight: CGFloat {
            switch self {
            case .regular:
                return 44
            case .compact:
                return 34
            }
        }

        fileprivate var padding: CGFloat {
            switch self {
            case .regular:
                return AppSpacing.md
            case .compact:
                return AppSpacing.sm
            }
        }
    }

    let title: String
    let value: String
    var style: Style = .subtle
    var density: Density = .regular

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(density.titleFont)
                .foregroundStyle(.secondary)

            Text(value)
                .font(density.valueFont)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: density.minHeight, alignment: .leading)
        .padding(density.padding)
        .background(style.fillStyle, in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
