//
//  ClinicalCardContainer.swift
//  Ars Medica Digitalis
//
//  Card reutilizable para secciones clínicas editables.
//  Encapsula encabezado, estado colapsado y estilo Liquid Glass.
//

import SwiftUI

struct ClinicalCardContainer<Content: View>: View {

    enum Style {
        case elevated
        case flat
    }

    let title: String
    let systemImage: String
    var style: Style = .flat
    var isCollapsed: Bool = false
    var onHeaderTap: (() -> Void)? = nil
    @ViewBuilder var content: Content

    private var cornerRadius: CGFloat {
        style == .elevated ? AppCornerRadius.lg : AppCornerRadius.md
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                header

                if !isCollapsed {
                    Divider()
                        .opacity(0.30)

                    content
                }
            }
            .padding(AppSpacing.cardPadding)
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

    @ViewBuilder
    private var header: some View {
        let headerContent = HStack(spacing: AppSpacing.sm) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            Spacer(minLength: 0)

            if onHeaderTap != nil {
                Image(systemName: isCollapsed ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())

        if let onHeaderTap {
            Button(action: onHeaderTap) {
                headerContent
            }
            .buttonStyle(.plain)
        } else {
            headerContent
        }
    }
}

#Preview("ClinicalCardContainer") {
    ScrollView {
        VStack(spacing: AppSpacing.md) {
            ClinicalCardContainer(
                title: "Antropometría",
                systemImage: "ruler",
                style: .elevated,
                isCollapsed: false
            ) {
                Text("Peso, altura y cintura")
                    .foregroundStyle(.secondary)
            }

            ClinicalCardContainer(
                title: "Estilo de vida",
                systemImage: "figure.walk",
                style: .flat,
                isCollapsed: true
            ) {
                Text("Contenido oculto en modo compacto")
            }
        }
        .padding(AppSpacing.lg)
    }
}
