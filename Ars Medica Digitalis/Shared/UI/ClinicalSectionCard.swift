//
//  ClinicalSectionCard.swift
//  Ars Medica Digitalis
//
//  Contenedor visual unificado para todas las secciones del dashboard clínico.
//  Fuente de verdad para padding, fondo, radio de esquinas y animación de aparición.
//
//  Todas las secciones deben pasar por este contenedor — directamente
//  (secciones colapsables vía DisclosureGroup) o indirectamente a través de SectionCard.
//

import SwiftUI

struct ClinicalSectionCard<Content: View>: View {

    @ViewBuilder let content: Content

    @State private var hasAppeared = false

    var body: some View {
        content
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .systemGroupedBackground),
                in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 14)
            .onAppear {
                guard !hasAppeared else { return }
                withAnimation(.easeOut(duration: 0.4)) {
                    hasAppeared = true
                }
            }
    }
}
