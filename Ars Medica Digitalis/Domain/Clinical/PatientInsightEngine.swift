//
//  PatientInsightEngine.swift
//  Ars Medica Digitalis
//
//  Compone riesgo y alertas clínicas en un insight único por paciente.
//

import Foundation

struct PatientInsight: Sendable, Equatable {
    let riskScore: Int
    let alerts: [PatientAlert]
    let adherence: Double
    let urgency: MentalHealthRiskUrgency
    let priorityLevel: MentalHealthRiskPriorityLevel
}

struct PatientInsightEngine: Sendable {

    private let riskEngine: MentalHealthRiskEngine
    private let alertEngine: AlertEngine

    init(
        riskEngine: MentalHealthRiskEngine = MentalHealthRiskEngine(),
        alertEngine: AlertEngine = AlertEngine()
    ) {
        self.riskEngine = riskEngine
        self.alertEngine = alertEngine
    }

    func buildInsight(snapshot: PatientClinicalSnapshot) -> PatientInsight {
        let risk = riskEngine.computeRisk(snapshot: snapshot)
        let alerts = alertEngine.alerts(for: snapshot)

        return PatientInsight(
            riskScore: risk.totalScore,
            alerts: alerts,
            adherence: snapshot.adherence,
            urgency: risk.urgency,
            priorityLevel: risk.priorityLevel
        )
    }
}
