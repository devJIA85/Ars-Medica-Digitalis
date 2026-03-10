import Foundation
import Testing
@testable import Ars_Medica_Digitalis

struct MentalHealthRiskEngineTests {

    private let engine = MentalHealthRiskEngine()

    @Test("MentalHealthRiskEngine produce score estable para seguimiento reciente y buena adherencia")
    func computeRiskStableCase() {
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

        let score = engine.computeRisk(snapshot: snapshot)

        #expect(score.totalScore < 30)
        #expect(score.priorityLevel == .stable)
        #expect(score.urgency == .routine)
        #expect(score.adherenceRisk == 17)
        #expect(score.dropoutRisk == 5)
    }

    @Test("MentalHealthRiskEngine eleva a moderado cuando cae la adherencia aunque exista seguimiento reciente")
    func computeRiskModerateCase() {
        let snapshot = PatientClinicalSnapshot(
            patientID: UUID(),
            lastSessionDate: nil,
            nextSessionDate: Date().addingTimeInterval(60 * 60 * 24 * 5),
            sessionCount: 10,
            completedSessions: 4,
            cancelledSessions: 4,
            adherence: 0.5,
            daysSinceLastSession: 9,
            diagnosisSummary: "Depresión",
            hasDebt: false
        )

        let score = engine.computeRisk(snapshot: snapshot)

        #expect((30..<60).contains(score.totalScore))
        #expect(score.priorityLevel == .moderate)
        #expect(score.urgency == .soon)
        #expect(score.adherenceRisk >= 50)
    }

    @Test("MentalHealthRiskEngine marca crítico cuando hay abandono prolongado, sin próxima cita y con deuda")
    func computeRiskCriticalCase() {
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

        let score = engine.computeRisk(snapshot: snapshot)

        #expect(score.totalScore >= 80)
        #expect(score.priorityLevel == .critical)
        #expect(score.urgency == .immediate)
        #expect(score.adherenceRisk >= 90)
        #expect(score.dropoutRisk == 100)
    }

    @Test("MentalHealthRiskEngine mapea prioridades en los cortes definidos")
    func priorityLevelBoundaries() {
        #expect(MentalHealthRiskEngine.priorityLevel(for: 0) == .stable)
        #expect(MentalHealthRiskEngine.priorityLevel(for: 29) == .stable)
        #expect(MentalHealthRiskEngine.priorityLevel(for: 30) == .moderate)
        #expect(MentalHealthRiskEngine.priorityLevel(for: 59) == .moderate)
        #expect(MentalHealthRiskEngine.priorityLevel(for: 60) == .high)
        #expect(MentalHealthRiskEngine.priorityLevel(for: 79) == .high)
        #expect(MentalHealthRiskEngine.priorityLevel(for: 80) == .critical)
        #expect(MentalHealthRiskEngine.priorityLevel(for: 100) == .critical)
    }

    @Test("MentalHealthRiskEngine aplica modificador clínico para severidades BDI-II")
    func computeRiskAppliesBDIClinicalModifier() {
        let baseSnapshot = PatientClinicalSnapshot(
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
        let severeSnapshot = PatientClinicalSnapshot(
            patientID: baseSnapshot.patientID,
            lastSessionDate: baseSnapshot.lastSessionDate,
            nextSessionDate: baseSnapshot.nextSessionDate,
            sessionCount: baseSnapshot.sessionCount,
            completedSessions: baseSnapshot.completedSessions,
            cancelledSessions: baseSnapshot.cancelledSessions,
            adherence: baseSnapshot.adherence,
            daysSinceLastSession: baseSnapshot.daysSinceLastSession,
            diagnosisSummary: baseSnapshot.diagnosisSummary,
            hasDebt: baseSnapshot.hasDebt,
            bdiSeverity: "severeDepression"
        )
        let extremeSnapshot = PatientClinicalSnapshot(
            patientID: baseSnapshot.patientID,
            lastSessionDate: baseSnapshot.lastSessionDate,
            nextSessionDate: baseSnapshot.nextSessionDate,
            sessionCount: baseSnapshot.sessionCount,
            completedSessions: baseSnapshot.completedSessions,
            cancelledSessions: baseSnapshot.cancelledSessions,
            adherence: baseSnapshot.adherence,
            daysSinceLastSession: baseSnapshot.daysSinceLastSession,
            diagnosisSummary: baseSnapshot.diagnosisSummary,
            hasDebt: baseSnapshot.hasDebt,
            bdiSeverity: "extremeDepression"
        )

        let baseScore = engine.computeRisk(snapshot: baseSnapshot).totalScore
        let severeScore = engine.computeRisk(snapshot: severeSnapshot).totalScore
        let extremeScore = engine.computeRisk(snapshot: extremeSnapshot).totalScore

        #expect(baseScore == 10)
        #expect(severeScore == baseScore + 15)
        #expect(extremeScore == baseScore + 25)
    }
}
