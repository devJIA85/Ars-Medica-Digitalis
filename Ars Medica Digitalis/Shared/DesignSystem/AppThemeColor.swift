//
//  AppThemeColor.swift
//  Ars Medica Digitalis
//
//  Paleta de colores de acento seleccionable por el profesional.
//
//  Nota: AppThemeColor y SessionTypeColorToken comparten los mismos
//  8 tokens de color (blue, teal, green, orange, red, pink, purple, indigo).
//  AppThemeColor agrega softFill/softStroke para uso en contextos de theming,
//  mientras que SessionTypeColorToken los usa para badges de tipos de sesión.
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

    /// Relleno suave (14% opacidad) para fondos de badge o contenedor.
    var softFill: Color {
        color.opacity(0.14)
    }

    /// Borde suave (20% opacidad) para stroke de badge o contenedor.
    var softStroke: Color {
        color.opacity(0.20)
    }

    /// Nombre visible en la interfaz de selección de tema.
    var displayName: String {
        switch self {
        case .blue:   "Azul"
        case .green:  "Verde"
        case .purple: "Púrpura"
        case .orange: "Naranja"
        case .red:    "Rojo"
        case .teal:   "Verde azulado"
        case .indigo: "Índigo"
        case .pink:   "Rosa"
        }
    }
}
