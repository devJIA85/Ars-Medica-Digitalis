//
//  SettingsSectionCard.swift
//  Ars Medica Digitalis
//
//  Card reutilizable para secciones de configuracion con jerarquia Liquid Glass.
//

import SwiftUI

struct GlassCardEntranceModifier: ViewModifier {

    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
            .scaleEffect(hasAppeared ? 1 : 0.985, anchor: .top)
            .onAppear {
                guard hasAppeared == false else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    func glassCardEntrance() -> some View {
        modifier(GlassCardEntranceModifier())
    }
}

struct SettingsSectionCard<Content: View>: View {

    enum Prominence {
        case standard
        case prominent
    }

    let title: String
    let systemImage: String
    var subtitle: String? = nil
    var prominence: Prominence = .standard
    @ViewBuilder var content: Content

    var body: some View {
        CardContainer(style: prominence == .prominent ? .elevated : .flat) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                header
                content
            }
        }
        .glassCardEntrance()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label {
                Text(title)
                    .font(.headline.weight(.semibold))
            } icon: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ScrollView {
        SettingsSectionCard(
            title: "Privacidad",
            systemImage: "lock.shield",
            subtitle: "Proteccion local del dispositivo."
        ) {
            Text("Contenido de ejemplo")
                .font(.body)
        }
        .padding(AppSpacing.lg)
    }
}
