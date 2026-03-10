//
//  MMSEModels.swift
//  Ars Medica Digitalis
//
//  Modelos JSON-driven para el Mini Mental State Examination (MMSE).
//

import Foundation

/// Modelo raíz del test MMSE.
/// Se mantiene alineado al JSON para evitar hardcodear estructura en la UI.
struct MMSETest: Decodable, Sendable, Identifiable {
    let id: String
    let domain: String
    let name: String
    let description: String
    let timeframe: String?
    let meta: MMSEMeta?
    let sections: [MMSESection]
    let scoring: MMSEScoring

    /// Puntaje máximo calculado desde `meta` o, si falta, desde los ítems scorable.
    /// Esto evita inconsistencias cuando cambie el JSON de origen.
    var maximumScore: Int {
        meta?.maxScore ?? sections.reduce(0) { partialResult, section in
            partialResult + section.scorableItems.reduce(0) { $0 + $1.effectiveMaxScore }
        }
    }

    /// Lista plana de ítems evaluables para cálculos de score y progreso.
    var scorableItems: [MMSEItem] {
        sections.flatMap(\.scorableItems)
    }
}

/// Metadatos clínicos del test.
struct MMSEMeta: Decodable, Sendable {
    let maxScore: Int?
    let version: String?
    let administeredBy: String?
}

/// Sección clínica del MMSE.
struct MMSESection: Decodable, Sendable, Identifiable {
    let id: String
    let title: String
    let maxScore: Int
    let items: [MMSEItem]

    /// Filtra sólo los ítems que realmente aportan puntaje.
    var scorableItems: [MMSEItem] {
        items.filter(\.isScorable)
    }
}

/// Tipos de ítem soportados por el JSON MMSE.
enum MMSEItemType: String, Decodable, Sendable {
    case boolean
    case instruction
    case drawing

    /// Los ítems de instrucción no puntúan; el resto sí.
    var isScorable: Bool {
        self != .instruction
    }
}

/// Ítem individual del MMSE.
struct MMSEItem: Decodable, Sendable, Identifiable {
    let id: String
    let type: MMSEItemType
    let title: String?
    let text: String?
    let maxScore: Int?

    /// Punto único para resolver si un ítem aporta score.
    var isScorable: Bool {
        type.isScorable
    }

    /// Puntaje efectivo por ítem: por defecto 1 para ítems scorable.
    /// Esto mantiene compatibilidad con MMSE JSON aunque omita `maxScore`.
    var effectiveMaxScore: Int {
        guard isScorable else { return 0 }
        return max(1, maxScore ?? 1)
    }

    /// Texto principal para mostrar en UI sin acoplarla a un campo puntual.
    var displayTitle: String {
        title ?? text ?? id
    }
}

/// Bloque de interpretación clínica del score.
struct MMSEScoring: Decodable, Sendable {
    let ranges: [MMSEScoringRange]

    /// Busca la interpretación aplicable al score total según rangos del JSON.
    func interpretation(for score: Int) -> MMSEScoringRange? {
        ranges.first { $0.contains(score) }
    }
}

/// Rango de scoring con metadatos visuales y de severidad.
struct MMSEScoringRange: Decodable, Sendable, Identifiable, Hashable {
    let min: Int
    let max: Int
    let label: String
    let severity: String
    let color: String

    var id: String {
        "\(min)-\(max)-\(label)"
    }

    func contains(_ score: Int) -> Bool {
        score >= min && score <= max
    }
}
