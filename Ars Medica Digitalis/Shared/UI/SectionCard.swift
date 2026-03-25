//
//  SectionCard.swift
//  Ars Medica Digitalis
//
//  Card con encabezado para secciones siempre visibles del dashboard clínico.
//  Delega el estilo visual (padding, fondo, radio, animación) a ClinicalSectionCard.
//
//  prominence: .primary  → .title3.weight(.semibold)   (ClinicalStatus, Medication)
//  prominence: .secondary → .subheadline.weight(.semibold) (PatientSummary, RiskFactors)
//

import SwiftUI

enum SectionProminence {
    case primary
    case secondary
}

struct SectionCard<Content: View, Action: View>: View {

    let title: String
    let icon: String?
    let prominence: SectionProminence
    @ViewBuilder let content: Content
    @ViewBuilder let action: Action

    init(
        title: String,
        icon: String? = nil,
        prominence: SectionProminence = .primary,
        @ViewBuilder content: () -> Content
    ) where Action == EmptyView {
        self.title = title
        self.icon = icon
        self.prominence = prominence
        self.content = content()
        self.action = EmptyView()
    }

    init(
        title: String,
        icon: String? = nil,
        prominence: SectionProminence = .primary,
        @ViewBuilder action: () -> Action,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.prominence = prominence
        self.content = content()
        self.action = action()
    }

    var body: some View {
        ClinicalSectionCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                header
                content
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Label {
                Text(title)
                    .font(headerFont)
                    .foregroundStyle(.primary)
            } icon: {
                if let icon {
                    Image(systemName: icon)
                        .font(headerFont)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            action
        }
    }

    private var headerFont: Font {
        prominence == .primary
            ? .title3.weight(.semibold)
            : .subheadline.weight(.semibold)
    }
}
