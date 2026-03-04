//
//  MentalHealthRiskEngine.swift
//  Ars Medica Digitalis
//
//  Motor puro de score clínico para priorización de seguimiento.
//

import Foundation

enum MentalHealthRiskUrgency: String, Sendable, Equatable {
    case routine
    case soon
    case urgent
    case immediate
}

enum MentalHealthRiskPriorityLevel: String, Sendable, Equatable {
    case stable
    case moderate
    case high
    case critical
}

struct MentalHealthRiskScore: Sendable, Equatable {
    let totalScore: Int
    let urgency: MentalHealthRiskUrgency
    let adherenceRisk: Int
    let dropoutRisk: Int
    let priorityLevel: MentalHealthRiskPriorityLevel
}

struct MentalHealthRiskEngine: Sendable {

    func computeRisk(snapshot: PatientClinicalSnapshot) -> MentalHealthRiskScore {
        let adherenceRisk = Self.computeAdherenceRisk(snapshot: snapshot)
        let dropoutRisk = Self.computeDropoutRisk(snapshot: snapshot)
        let totalScore = Self.clamp(
            Int(
                round(
                    (Double(adherenceRisk) * 0.45)
                    + (Double(dropoutRisk) * 0.55)
                )
            ),
            lower: 0,
            upper: 100
        )

        return MentalHealthRiskScore(
            totalScore: totalScore,
            urgency: Self.computeUrgency(
                totalScore: totalScore,
                adherenceRisk: adherenceRisk,
                dropoutRisk: dropoutRisk,
                snapshot: snapshot
            ),
            adherenceRisk: adherenceRisk,
            dropoutRisk: dropoutRisk,
            priorityLevel: Self.priorityLevel(for: totalScore)
        )
    }

    static func priorityLevel(for totalScore: Int) -> MentalHealthRiskPriorityLevel {
        let normalizedScore = clamp(totalScore, lower: 0, upper: 100)

        switch normalizedScore {
        case 0..<30:
            return .stable
        case 30..<60:
            return .moderate
        case 60..<80:
            return .high
        default:
            return .critical
        }
    }

    private static func computeAdherenceRisk(snapshot: PatientClinicalSnapshot) -> Int {
        let normalizedAdherence = min(max(snapshot.adherence, 0), 1)
        let baseRisk = Int(round((1 - normalizedAdherence) * 70))
        let cancellationPenalty = min(snapshot.cancelledSessions * 8, 24)
        let debtPenalty = snapshot.hasDebt ? 8 : 0

        return clamp(
            baseRisk + cancellationPenalty + debtPenalty,
            lower: 0,
            upper: 100
        )
    }

    private static func computeDropoutRisk(snapshot: PatientClinicalSnapshot) -> Int {
        let inactivityRisk: Int = {
            guard let days = snapshot.daysSinceLastSession else {
                return snapshot.nextSessionDate == nil ? 35 : 10
            }

            switch days {
            case ..<7:
                return 5
            case 7..<14:
                return 20
            case 14..<30:
                return 40
            case 30..<60:
                return 65
            default:
                return 85
            }
        }()

        let upcomingPenalty = snapshot.nextSessionDate == nil ? 20 : 0
        let lowEngagementPenalty = snapshot.sessionCount <= 1 ? 10 : 0
        let diagnosisPenalty = snapshot.diagnosisSummary == nil ? 5 : 0
        let debtPenalty = snapshot.hasDebt ? 10 : 0

        return clamp(
            inactivityRisk
            + upcomingPenalty
            + lowEngagementPenalty
            + diagnosisPenalty
            + debtPenalty,
            lower: 0,
            upper: 100
        )
    }

    private static func computeUrgency(
        totalScore: Int,
        adherenceRisk: Int,
        dropoutRisk: Int,
        snapshot: PatientClinicalSnapshot
    ) -> MentalHealthRiskUrgency {
        if totalScore >= 80 || (dropoutRisk >= 85 && snapshot.nextSessionDate == nil) {
            return .immediate
        }

        if totalScore >= 60 || dropoutRisk >= 70 {
            return .urgent
        }

        if totalScore >= 30 || adherenceRisk >= 40 {
            return .soon
        }

        return .routine
    }

    private static func clamp(
        _ value: Int,
        lower: Int,
        upper: Int
    ) -> Int {
        min(max(value, lower), upper)
    }
}
