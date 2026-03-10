//
//  BDISeverityLevel.swift
//  Ars Medica Digitalis
//
//  Normaliza severidades BDI-II para soportar formatos legacy y actuales.
//

import Foundation

enum BDISeverityLevel: Sendable, Equatable {
    case low
    case moderate
    case severe
    case extreme

    var clinicalRiskModifier: Int {
        switch self {
        case .low:
            0
        case .moderate:
            8
        case .severe:
            15
        case .extreme:
            25
        }
    }

    var isHighDepression: Bool {
        switch self {
        case .severe, .extreme:
            true
        case .low, .moderate:
            false
        }
    }

    static func from(rawSeverity: String?) -> BDISeverityLevel? {
        guard let rawSeverity,
              rawSeverity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return nil
        }

        let normalized = normalize(rawSeverity)

        if normalized.contains("extreme") || normalized.contains("extrema") {
            return .extreme
        }

        if normalized.contains("severe") || normalized.contains("grave") {
            return .severe
        }

        if normalized.contains("moderate") || normalized.contains("moderada") {
            return .moderate
        }

        if normalized == "normal"
            || normalized == "minimal"
            || normalized.contains("mild")
            || normalized.contains("intermittent")
        {
            return .low
        }

        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
