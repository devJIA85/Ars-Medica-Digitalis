//
//  AppearanceSection.swift
//  Ars Medica Digitalis
//
//  Preferencias visuales del perfil.
//

import SwiftUI

enum ProfileColorSchemeOption: String, CaseIterable, SegmentedSelectorOption {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }
}

struct AppearanceSection: View {

    @Binding var selection: ProfileColorSchemeOption

    var body: some View {
        SettingsSectionCard(
            title: "Apariencia",
            systemImage: "paintbrush",
            subtitle: "Respeta el modo del sistema o fija una preferencia local."
        ) {
            SegmentedSelector(
                title: "Modo",
                options: ProfileColorSchemeOption.allCases,
                selection: $selection
            )
        }
    }
}
