//
//  ClinicalFABView.swift
//  Ars Medica Digitalis
//
//  FAB clínico con Liquid Glass morph effect (iOS 26).
//  Un botón compacto que se expande en tres acciones clínicas frecuentes
//  usando GlassEffectContainer + glassEffectID para la animación morph.
//

import SwiftUI

struct ClinicalFABView: View {

    let onNuevaSession: () -> Void
    let onAgregarDiagnostico: () -> Void
    let onHistoriaClinica: () -> Void

    @State private var isExpanded: Bool = false
    @Namespace private var namespace

    var body: some View {
        // GlassEffectContainer agrupa los elementos para coordinar el morph effect
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .center, spacing: 8) {

                // Badges de acción — aparecen/desaparecen con morph
                if isExpanded {
                    VStack(spacing: 8) {
                        fabBadge(
                            systemImage: "heart.text.clipboard",
                            label: "Historia clínica",
                            id: "fab-hc",
                            action: { onHistoriaClinica(); collapse() }
                        )
                        fabBadge(
                            systemImage: "stethoscope",
                            label: "Agregar diagnóstico",
                            id: "fab-dx",
                            action: { onAgregarDiagnostico(); collapse() }
                        )
                        fabBadge(
                            systemImage: "calendar.badge.plus",
                            label: "Nueva sesión",
                            id: "fab-session",
                            action: { onNuevaSession(); collapse() }
                        )
                    }
                }

                // Botón toggle — se morphea con los badges al expandir/colapsar
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.title3.weight(.semibold))
                        .frame(width: 48, height: 48)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .glassEffectID("fab-toggle", in: namespace)
                .accessibilityLabel(isExpanded ? "Cerrar acciones" : "Abrir acciones rápidas")
            }
        }
    }

    @ViewBuilder
    private func fabBadge(
        systemImage: String,
        label: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .frame(width: 20)
                Text(label)
                    .font(.callout.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        // Liquid Glass en forma de píldora redondeada
        .glassEffect(.regular, in: .rect(cornerRadius: AppCornerRadius.sm))
        // ID único para coordinar la animación morph con el botón toggle
        .glassEffectID(id, in: namespace)
        .accessibilityLabel(label)
    }

    private func collapse() {
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            isExpanded = false
        }
    }
}
