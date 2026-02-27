//
//  CardContainer.swift
//  Ars Medica Digitalis
//
//  Contenedor de card reutilizable con soporte para Liquid Glass nativo (iOS 26).
//  Extraído de CardShell (PatientDetailView) para unificar el estilo de cards
//  en todas las vistas y eliminar la inconsistencia entre PatientListView y
//  PatientDetailView que usaban dos implementaciones distintas.
//

import SwiftUI

struct CardContainer<Content: View>: View {

    enum Style {
        /// Card prominente: regularMaterial + glassEffect .regular + sombra mayor
        case elevated
        /// Card sutil: thinMaterial + glassEffect .clear + sombra menor
        case flat
    }

    var title: String? = nil
    var systemImage: String? = nil
    var style: Style = .flat
    @ViewBuilder var content: Content

    private var cornerRadius: CGFloat {
        style == .elevated ? AppCornerRadius.lg : AppCornerRadius.md
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let title {
                    Label {
                        Text(title)
                            .font(.title3.bold())
                    } icon: {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                content
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                style == .elevated ? .regularMaterial : .thinMaterial,
                in: shape
            )
        }
        .glassEffect(style == .elevated ? .regular : .clear, in: shape)
        .clipShape(shape)
        .shadow(
            color: .black.opacity(style == .elevated ? 0.10 : 0.08),
            radius: style == .elevated ? 10 : 8,
            y: style == .elevated ? 4 : 2
        )
    }
}

// MARK: - Preview

#Preview("CardContainer — variantes") {
    ScrollView {
        VStack(spacing: AppSpacing.sectionGap) {
            CardContainer(title: "Card Elevated", systemImage: "star.fill", style: .elevated) {
                Text("Contenido con estilo prominente, regularMaterial y sombra mayor.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            CardContainer(title: "Card Flat", systemImage: "square.grid.2x2", style: .flat) {
                Text("Contenido con estilo sutil, thinMaterial y sombra menor.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            CardContainer(style: .flat) {
                Text("Card sin título ni ícono.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.lg)
    }
}
