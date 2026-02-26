//
//  ClinicalStatusMapping.swift
//  Ars Medica Digitalis
//
//  Mapeo centralizado para estado clinico del paciente.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum ClinicalStatusMapping: String, CaseIterable {
    case estable = "estable"
    case activo = "activo"
    case riesgo = "riesgo"

    init?(clinicalStatusRawValue value: String) {
        switch value.normalizedClinicalStatusKey {
        case "estable":
            self = .estable
        case "activo":
            self = .activo
        case "riesgo":
            self = .riesgo
        default:
            return nil
        }
    }

    var label: String {
        switch self {
        case .estable: return L10n.tr("patient.clinical_status.estable")
        case .activo: return L10n.tr("patient.clinical_status.activo")
        case .riesgo: return L10n.tr("patient.clinical_status.riesgo")
        }
    }
}

#if canImport(SwiftUI)
extension ClinicalStatusMapping {
    var tint: Color {
        switch self {
        case .estable: return .green
        case .activo: return .orange
        case .riesgo: return .red
        }
    }
}
#endif

private extension String {
    var normalizedClinicalStatusKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
