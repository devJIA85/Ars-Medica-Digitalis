//
//  AlertEngine.swift
//  Ars Medica Digitalis
//
//  Motor puro de alertas clínicas derivadas del snapshot del paciente.
//

import Foundation

struct PatientAlert: Sendable, Equatable, Hashable {

    enum Kind: String, Sendable, Hashable {
        case noSession30Days
        case highDropoutRisk
        case lowAdherence
        case unpaidBalance
        case highDepressionScore
    }

    let kind: Kind

    static let noSession30Days = PatientAlert(kind: .noSession30Days)
    static let highDropoutRisk = PatientAlert(kind: .highDropoutRisk)
    static let lowAdherence = PatientAlert(kind: .lowAdherence)
    static let unpaidBalance = PatientAlert(kind: .unpaidBalance)
    static let highDepressionScore = PatientAlert(kind: .highDepressionScore)
}

struct AlertEngine: Sendable {

    func alerts(for snapshot: PatientClinicalSnapshot) -> [PatientAlert] {
        let risk = MentalHealthRiskEngine().computeRisk(snapshot: snapshot)
        var alerts: [PatientAlert] = []

        if let daysSinceLastSession = snapshot.daysSinceLastSession,
           daysSinceLastSession >= 30 {
            alerts.append(.noSession30Days)
        }

        if risk.dropoutRisk >= 70 {
            alerts.append(.highDropoutRisk)
        }

        if risk.adherenceRisk >= 40 {
            alerts.append(.lowAdherence)
        }

        if snapshot.hasDebt {
            alerts.append(.unpaidBalance)
        }

        if BDISeverityLevel.from(rawSeverity: snapshot.bdiSeverity)?.isHighDepression == true {
            alerts.append(.highDepressionScore)
        }

        return alerts
    }
}
