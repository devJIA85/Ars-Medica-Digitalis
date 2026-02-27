//
//  SectionContainer.swift
//  Ars Medica Digitalis
//
//  Envoltorio ligero para bloques de contenido agrupado dentro de una vista.
//  A diferencia de CardContainer, SectionContainer no aplica material ni sombra:
//  está pensado para organizar contenido dentro de un CardContainer o ScrollView,
//  no para ser el contenedor externo de una sección.
//

import SwiftUI

struct SectionContainer<Content: View>: View {

    let title: String
    var systemImage: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("SectionContainer") {
    ScrollView {
        VStack(spacing: AppSpacing.sectionGap) {
            CardContainer(style: .flat) {
                SectionContainer(title: "Datos personales", systemImage: "person.crop.circle") {
                    Text("Nombre · Edad · Género")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            CardContainer(style: .elevated) {
                SectionContainer(title: "Diagnósticos", systemImage: "stethoscope") {
                    Text("CIE-11 · Diagnóstico principal")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppSpacing.lg)
    }
}
