//
//  SessionTypeMapping.swift
//  Ars Medica Digitalis
//
//  Mapeo centralizado para modalidades de sesion.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum SessionTypeMapping: String, CaseIterable {
    case presencial = "presencial"
    case videollamada = "videollamada"
    case telefonica = "telefónica"

    init?(sessionTypeRawValue value: String) {
        switch value.normalizedSessionTypeKey {
        case "presencial":
            self = .presencial
        case "videollamada":
            self = .videollamada
        case "telefonica":
            self = .telefonica
        default:
            return nil
        }
    }

    var label: String {
        switch self {
        case .presencial: return L10n.tr("session.type.presencial")
        case .videollamada: return L10n.tr("session.type.videollamada")
        case .telefonica: return L10n.tr("session.type.telefonica")
        }
    }

    var abbreviatedLabel: String {
        switch self {
        case .presencial: return L10n.tr("session.type.presencial.abbrev")
        case .videollamada: return L10n.tr("session.type.videollamada.abbrev")
        case .telefonica: return L10n.tr("session.type.telefonica.abbrev")
        }
    }

    var icon: String {
        switch self {
        case .presencial: return "person.2.wave.2"
        case .videollamada: return "video"
        case .telefonica: return "phone"
        }
    }
}

#if canImport(SwiftUI)
extension SessionTypeMapping {
    var tint: Color {
        switch self {
        case .presencial: return .teal
        case .videollamada: return .indigo
        case .telefonica: return .orange
        }
    }
}
#endif

private extension String {
    var normalizedSessionTypeKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
