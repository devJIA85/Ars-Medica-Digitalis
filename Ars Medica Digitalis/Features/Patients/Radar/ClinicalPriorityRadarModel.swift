//
//  ClinicalPriorityRadarModel.swift
//  Ars Medica Digitalis
//
//  Modelo liviano para representar la distribución de prioridad clínica.
//

import Foundation

enum ClinicalPriorityBucket: String, CaseIterable, Identifiable, Sendable {
    case critical
    case attention
    case stable

    var id: String { rawValue }
}

struct ClinicalPriorityRadarModel: Equatable, Sendable {
    let totalCount: Int
    let criticalCount: Int
    let attentionCount: Int
    let stableCount: Int

    let criticalFraction: Double
    let attentionFraction: Double
    let stableFraction: Double

    init(
        totalCount: Int,
        criticalCount: Int,
        attentionCount: Int,
        stableCount: Int
    ) {
        let safeTotal = max(totalCount, 0)
        let safeCritical = max(criticalCount, 0)
        let safeAttention = max(attentionCount, 0)
        let safeStable = max(stableCount, 0)

        self.totalCount = safeTotal
        self.criticalCount = safeCritical
        self.attentionCount = safeAttention
        self.stableCount = safeStable

        guard safeTotal > 0 else {
            criticalFraction = 0
            attentionFraction = 0
            stableFraction = 0
            return
        }

        let denominator = Double(safeTotal)
        criticalFraction = Double(safeCritical) / denominator
        attentionFraction = Double(safeAttention) / denominator
        stableFraction = Double(safeStable) / denominator
    }

    func count(for bucket: ClinicalPriorityBucket) -> Int {
        switch bucket {
        case .critical:
            criticalCount
        case .attention:
            attentionCount
        case .stable:
            stableCount
        }
    }

    static let empty = ClinicalPriorityRadarModel(
        totalCount: 0,
        criticalCount: 0,
        attentionCount: 0,
        stableCount: 0
    )
}

