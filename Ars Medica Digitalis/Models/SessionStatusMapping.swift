//
//  SessionStatusMapping.swift
//  Ars Medica Digitalis
//
//  Mapeo centralizado para estados de sesion.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum SessionStatusMapping: String, CaseIterable {
    case programada = "programada"
    case completada = "completada"
    case cancelada = "cancelada"

    init?(sessionStatusRawValue value: String) {
        switch value.normalizedSessionStatusKey {
        case "programada":
            self = .programada
        case "completada":
            self = .completada
        case "cancelada":
            self = .cancelada
        default:
            return nil
        }
    }

    var label: String {
        switch self {
        case .programada: return L10n.tr("session.status.programada")
        case .completada: return L10n.tr("session.status.completada")
        case .cancelada: return L10n.tr("session.status.cancelada")
        }
    }

    var pluralLabel: String {
        switch self {
        case .programada: return L10n.tr("session.status.programada.plural")
        case .completada: return L10n.tr("session.status.completada.plural")
        case .cancelada: return L10n.tr("session.status.cancelada.plural")
        }
    }

    var icon: String {
        switch self {
        case .programada: return "clock"
        case .completada: return "checkmark.circle.fill"
        case .cancelada: return "xmark.circle.fill"
        }
    }
}

#if canImport(SwiftUI)
extension SessionStatusMapping {
    var tint: Color {
        switch self {
        case .programada: return .blue
        case .completada: return .green
        case .cancelada: return .red
        }
    }
}
#endif

private extension String {
    var normalizedSessionStatusKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
