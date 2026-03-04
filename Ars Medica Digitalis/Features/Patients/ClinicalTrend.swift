//
//  ClinicalTrend.swift
//  Ars Medica Digitalis
//
//  Modelo de tendencia clínica para el encabezado de insights.
//

import Foundation

enum ClinicalTrendDirection: String, Equatable, Sendable {
    case up
    case down
    case flat

    var symbol: String {
        switch self {
        case .up:
            "↑"
        case .down:
            "↓"
        case .flat:
            "→"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .up:
            L10n.tr("patient.dashboard.clinical_trend.direction.up")
        case .down:
            L10n.tr("patient.dashboard.clinical_trend.direction.down")
        case .flat:
            L10n.tr("patient.dashboard.clinical_trend.direction.flat")
        }
    }
}

enum ClinicalTrendTone: String, Equatable, Sendable {
    case positive
    case caution
    case neutral
}

struct ClinicalTrend: Identifiable, Equatable, Sendable {
    let id: String
    let systemImage: String
    let displayLabel: String
    let tone: ClinicalTrendTone
    let accessibilityLabel: String
}
