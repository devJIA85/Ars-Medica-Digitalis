import Foundation
import Testing
@testable import Ars_Medica_Digitalis

struct PatientInsightEngineTests {

    private let engine = PatientInsightEngine()

    @Test("PatientInsightEngine compone score, urgencia, prioridad y alertas desde el snapshot")
    func buildInsightComposesRiskAndAlerts() {
        let snapshot = PatientClinicalSnapshot(
            patientID: UUID(),
            lastSessionDate: nil,
            nextSessionDate: nil,
            sessionCount: 1,
            completedSessions: 1,
            cancelledSessions: 6,
            adherence: 0.14,
            daysSinceLastSession: 95,
            diagnosisSummary: "Riesgo de recaída",
            hasDebt: true
        )

        let insight = engine.buildInsight(snapshot: snapshot)

        #expect(insight.riskScore == 96)
        #expect(insight.adherence == 0.14)
        #expect(insight.urgency == .immediate)
        #expect(insight.priorityLevel == .critical)
        #expect(
            insight.alerts == [
                .noSession30Days,
                .highDropoutRisk,
                .lowAdherence,
                .unpaidBalance,
            ]
        )
    }

    @Test("PatientInsightEngine preserva adherencia del snapshot y no agrega alertas extra")
    func buildInsightStableSnapshot() {
        let snapshot = PatientClinicalSnapshot(
            patientID: UUID(),
            lastSessionDate: nil,
            nextSessionDate: Date().addingTimeInterval(60 * 60 * 24 * 3),
            sessionCount: 8,
            completedSessions: 7,
            cancelledSessions: 1,
            adherence: 0.875,
            daysSinceLastSession: 3,
            diagnosisSummary: "Ansiedad",
            hasDebt: false
        )

        let insight = engine.buildInsight(snapshot: snapshot)

        #expect(insight.riskScore == 10)
        #expect(insight.adherence == snapshot.adherence)
        #expect(insight.urgency == .routine)
        #expect(insight.priorityLevel == .stable)
        #expect(insight.alerts.isEmpty)
    }
}
