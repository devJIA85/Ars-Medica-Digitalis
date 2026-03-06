//
//  AppThemeColor.swift
//  Ars Medica Digitalis
//
//  Paleta de colores de acento seleccionable por el profesional.
//

import SwiftUI

/// Define los colores de tema disponibles para personalizar la interfaz.
/// El valor raw es String para compatibilidad directa con @AppStorage.
enum AppThemeColor: String, CaseIterable, Sendable, Identifiable {
    case blue
    case green
    case purple
    case orange
    case red
    case teal
    case indigo
    case pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:   .blue
        case .green:  .green
        case .purple: .purple
        case .orange: .orange
        case .red:    .red
        case .teal:   .teal
        case .indigo: .indigo
        case .pink:   .pink
        }
    }

    /// Nombre visible en la interfaz de seleccion de tema.
    var displayName: String {
        switch self {
        case .blue:   "Azul"
        case .green:  "Verde"
        case .purple: "Purpura"
        case .orange: "Naranja"
        case .red:    "Rojo"
        case .teal:   "Verde azulado"
        case .indigo: "Indigo"
        case .pink:   "Rosa"
        }
    }
}
