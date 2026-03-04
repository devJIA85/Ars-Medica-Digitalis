//
//  SessionTypeAppearance.swift
//  Ars Medica Digitalis
//
//  Tokens visuales reutilizables para tipos facturables.
//

import SwiftUI

enum SessionTypeColorToken: String, CaseIterable, Codable, Sendable, Identifiable {
    case blue
    case teal
    case green
    case orange
    case red
    case pink
    case purple
    case indigo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "Azul"
        case .teal: "Turquesa"
        case .green: "Verde"
        case .orange: "Naranja"
        case .red: "Rojo"
        case .pink: "Rosa"
        case .purple: "Violeta"
        case .indigo: "Indigo"
        }
    }

    var color: Color {
        switch self {
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        case .indigo: .indigo
        }
    }

    var softFill: Color {
        color.opacity(0.14)
    }

    var softStroke: Color {
        color.opacity(0.20)
    }
}

struct SessionTypeSymbolOption: Identifiable, Hashable, Sendable {
    let systemName: String
    let title: String

    var id: String { systemName }
}

enum SessionTypeSymbolCatalog {
    static let defaultSymbolName = "banknote.fill"

    static let options: [SessionTypeSymbolOption] = [
        SessionTypeSymbolOption(systemName: "banknote.fill", title: "Billete"),
        SessionTypeSymbolOption(systemName: "stethoscope", title: "Consulta"),
        SessionTypeSymbolOption(systemName: "heart.text.square.fill", title: "Salud"),
        SessionTypeSymbolOption(systemName: "brain.head.profile", title: "Psiquis"),
        SessionTypeSymbolOption(systemName: "person.2.fill", title: "Pareja"),
        SessionTypeSymbolOption(systemName: "figure.2.and.child.holdinghands", title: "Familia"),
        SessionTypeSymbolOption(systemName: "cross.case.fill", title: "Clinica"),
        SessionTypeSymbolOption(systemName: "waveform.path.ecg", title: "Evaluacion"),
        SessionTypeSymbolOption(systemName: "moon.stars.fill", title: "Bienestar"),
        SessionTypeSymbolOption(systemName: "house.fill", title: "Domicilio"),
        SessionTypeSymbolOption(systemName: "video.fill", title: "Virtual"),
        SessionTypeSymbolOption(systemName: "person.fill.questionmark", title: "Admision"),
    ]

    static func isSupported(_ systemName: String) -> Bool {
        options.contains(where: { $0.systemName == systemName })
    }
}

extension SessionCatalogType {
    var resolvedColorToken: SessionTypeColorToken {
        SessionTypeColorToken(rawValue: colorToken) ?? .blue
    }

    var resolvedSymbolName: String {
        SessionTypeSymbolCatalog.isSupported(iconSystemName)
        ? iconSystemName
        : SessionTypeSymbolCatalog.defaultSymbolName
    }
}
