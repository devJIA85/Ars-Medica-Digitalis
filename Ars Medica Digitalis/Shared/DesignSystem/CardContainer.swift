//
//  CardContainer.swift
//  Ars Medica Digitalis
//
//  Contenedor de card reutilizable con soporte para Liquid Glass nativo (iOS 26).
//  Extraído de CardShell (PatientDetailView) para unificar el estilo de cards
//  en todas las vistas y eliminar la inconsistencia entre PatientListView y
//  PatientDetailView que usaban dos implementaciones distintas.
//
//  Fix: cuando usesGlassEffect = true, el background material lo provee
//  .glassEffect() directamente. Aplicar ambos creaba un artefacto visual
//  de doble capa bajo fondos dinámicos en iOS 26.
//

import SwiftUI

struct CardContainer<Content: View>: View {

    enum Style {
        /// Card prominente: regularMaterial + glassEffect .regular + sombra mayor
        case elevated
        /// Card sutil: thinMaterial + glassEffect .clear + sombra menor
        case flat
    }

    enum BackgroundStyle {
        case material
        case solid(Color)
    }

    var title: String? = nil
    var systemImage: String? = nil
    var style: Style = .flat
    var usesGlassEffect: Bool = true
    var backgroundStyle: BackgroundStyle = .material
    @ViewBuilder var content: Content

    private var cornerRadius: CGFloat {
        style == .elevated ? AppCornerRadius.lg : AppCornerRadius.md
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var cardFillStyle: AnyShapeStyle {
        switch backgroundStyle {
        case .material:
            return AnyShapeStyle(style == .elevated ? .regularMaterial : .thinMaterial)
        case .solid(let color):
            return AnyShapeStyle(color)
        }
    }

    var body: some View {
        Group {
            if usesGlassEffect {
                // glassEffect gestiona el material visualmente —
                // no se aplica background adicional para evitar doble capa.
                GlassEffectContainer {
                    rawCardContent
                }
                .glassEffect(style == .elevated ? .regular : .clear, in: shape)
            } else {
                // Sin glassEffect, el material se aplica explícitamente.
                rawCardContent
                    .background(cardFillStyle, in: shape)
            }
        }
        .clipShape(shape)
        .shadow(
            color: .black.opacity(style == .elevated ? 0.10 : 0.08),
            radius: style == .elevated ? 10 : 8,
            y: style == .elevated ? 4 : 2
        )
    }

    /// Contenido sin background propio; el contexto padre decide el tratamiento.
    private var rawCardContent: some View {
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
