import Foundation
import Testing
@testable import Ars_Medica_Digitalis

struct AlertEngineTests {

    private let engine = AlertEngine()

    @Test("AlertEngine no emite alertas para un snapshot estable")
    func alertsStableSnapshot() {
        let snapshot = PatientClinicalSnapshot(
            patientID: UUID(),
            lastSessionDate: nil,
            nextSessionDate: Date().addingTimeInterval(60 * 60 * 24 * 4),
            sessionCount: 8,
            completedSessions: 7,
            cancelledSessions: 1,
            adherence: 0.875,
            daysSinceLastSession: 3,
            diagnosisSummary: "Ansiedad",
            hasDebt: false
        )

        #expect(engine.alerts(for: snapshot).isEmpty)
    }

    @Test("AlertEngine emite alertas en orden fijo y determinístico")
    func alertsOrderIsDeterministic() {
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

        let firstPass = engine.alerts(for: snapshot)
        let secondPass = engine.alerts(for: snapshot)

        #expect(firstPass == secondPass)
        #expect(
            firstPass == [
                .noSession30Days,
                .highDropoutRisk,
                .lowAdherence,
                .unpaidBalance,
            ]
        )
    }

    @Test("AlertEngine usa umbrales independientes para adherencia, dropout y deuda")
    func alertsThresholds() {
        let snapshot = PatientClinicalSnapshot(
            patientID: UUID(),
            lastSessionDate: nil,
            nextSessionDate: Date().addingTimeInterval(60 * 60 * 24 * 2),
            sessionCount: 10,
            completedSessions: 4,
            cancelledSessions: 4,
            adherence: 0.5,
            daysSinceLastSession: 9,
            diagnosisSummary: "Depresión",
            hasDebt: true
        )

        let alerts = engine.alerts(for: snapshot)

        #expect(alerts.contains(.lowAdherence))
        #expect(alerts.contains(.unpaidBalance))
        #expect(alerts.contains(.highDropoutRisk) == false)
        #expect(alerts.contains(.noSession30Days) == false)
    }

    @Test("AlertEngine detecta BDI alto con severidad BDI-II normalizada")
    func alertsDetectHighBDISeverity() {
        let snapshot = PatientClinicalSnapshot(
            patientID: UUID(),
            lastSessionDate: nil,
            nextSessionDate: Date().addingTimeInterval(60 * 60 * 24 * 4),
            sessionCount: 8,
            completedSessions: 7,
            cancelledSessions: 1,
            adherence: 0.875,
            daysSinceLastSession: 3,
            diagnosisSummary: "Depresión",
            hasDebt: false,
            bdiScore: 48,
            bdiSeverity: "extremeDepression"
        )

        let alerts = engine.alerts(for: snapshot)

        #expect(alerts.contains(.highDepressionScore))
    }
}
