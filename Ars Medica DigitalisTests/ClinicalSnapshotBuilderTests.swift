import Foundation
import Testing
@testable import Ars_Medica_Digitalis

@MainActor
struct ClinicalSnapshotBuilderTests {

    @Test("ClinicalSnapshotBuilder precalcula métricas clínicas y deuda del paciente")
    func buildSnapshotsPrecomputesPatientMetrics() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 6, hour: 12, calendar: calendar)
        let patientID = UUID()

        let patient = Patient(
            id: patientID,
            firstName: "Ana",
            lastName: "García",
            currencyCode: "ARS"
        )

        let principal = Diagnosis(
            icdCode: "QE84",
            icdTitleEs: "Reacción aguda al estrés",
            diagnosisType: .principal
        )
        let secondary = Diagnosis(
            icdCode: "6D10.Z",
            icdTitleEs: "Ansiedad no especificada",
            diagnosisType: .secundario
        )
        patient.activeDiagnoses = [secondary, principal]

        let olderCompletedDate = makeDate(year: 2026, month: 3, day: 1, hour: 9, calendar: calendar)
        let latestCompletedDate = makeDate(year: 2026, month: 3, day: 4, hour: 17, calendar: calendar)
        let cancelledDate = makeDate(year: 2026, month: 3, day: 5, hour: 14, calendar: calendar)
        let nextScheduledDate = makeDate(year: 2026, month: 3, day: 7, hour: 10, calendar: calendar)

        let completedWithDebt = Session(
            sessionDate: olderCompletedDate,
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "ARS",
            payments: [
                Payment(amount: 20, currencyCode: "ARS", session: nil)
            ]
        )
        let latestCompleted = Session(
            sessionDate: latestCompletedDate,
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            finalPriceSnapshot: 80,
            finalCurrencySnapshot: "ARS"
        )
        let cancelled = Session(
            sessionDate: cancelledDate,
            status: SessionStatusMapping.cancelada.rawValue,
            patient: patient
        )
        let scheduled = Session(
            sessionDate: nextScheduledDate,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        patient.sessions = [completedWithDebt, latestCompleted, cancelled, scheduled]

        let snapshots = ClinicalSnapshotBuilder.buildSnapshots(
            patients: [patient],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let snapshot = snapshots[patientID]

        #expect(snapshot?.patientID == patientID)
        #expect(snapshot?.lastSessionDate == latestCompletedDate)
        #expect(snapshot?.nextSessionDate == nextScheduledDate)
        #expect(snapshot?.sessionCount == 4)
        #expect(snapshot?.completedSessions == 2)
        #expect(snapshot?.cancelledSessions == 1)
        #expect(snapshot?.adherence == (2.0 / 3.0))
        #expect(snapshot?.daysSinceLastSession == 2)
        #expect(snapshot?.diagnosisSummary == "Reacción aguda al estrés +1")
        #expect(snapshot?.hasDebt == true)
    }

    @Test("ClinicalSnapshotBuilder usa diagnósticos de la última sesión completada si no hay activos")
    func buildSnapshotsFallsBackToLatestCompletedSessionDiagnoses() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 5, hour: 9, calendar: calendar)
        let patientID = UUID()

        let patient = Patient(id: patientID, firstName: "Luis", lastName: "Paz")
        let oldDiagnosis = Diagnosis(
            icdCode: "6D10.Z",
            icdTitleEs: "Ansiedad no especificada",
            diagnosisType: .principal
        )
        let latestDiagnosis = Diagnosis(
            icdCode: "6B40",
            icdTitleEs: "Estrés, no clasificado en otra parte",
            diagnosisType: .principal
        )

        let oldSession = Session(
            sessionDate: makeDate(year: 2026, month: 3, day: 1, hour: 11, calendar: calendar),
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            diagnoses: [oldDiagnosis]
        )
        let latestSession = Session(
            sessionDate: makeDate(year: 2026, month: 3, day: 4, hour: 11, calendar: calendar),
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            diagnoses: [latestDiagnosis]
        )
        patient.sessions = [oldSession, latestSession]

        let snapshots = ClinicalSnapshotBuilder.buildSnapshots(
            patients: [patient],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(snapshots[patientID]?.diagnosisSummary == "Estrés")
        #expect(snapshots[patientID]?.daysSinceLastSession == 1)
    }

    @Test("ClinicalSnapshotBuilder resuelve deuda con precios en memoria aunque falten snapshots finales")
    func buildSnapshotsDetectsDebtWithoutFinalPriceSnapshots() {
        let calendar = makeCalendar()
        let referenceDate = makeDate(year: 2026, month: 3, day: 6, hour: 12, calendar: calendar)

        let professional = Professional(fullName: "Profesional")
        let sessionType = SessionCatalogType(name: "Individual", professional: professional)
        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: makeDate(year: 2026, month: 3, day: 1, hour: 8, calendar: calendar),
            price: 120,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        sessionType.priceVersions = [priceVersion]
        professional.sessionCatalogTypes = [sessionType]

        let patient = Patient(
            firstName: "Mara",
            lastName: "Lopez",
            professional: professional
        )
        let currencyVersion = PatientCurrencyVersion(
            currencyCode: "USD",
            effectiveFrom: makeDate(year: 2026, month: 3, day: 1, hour: 0, calendar: calendar),
            patient: patient
        )
        patient.currencyVersions = [currencyVersion]

        let session = Session(
            sessionDate: makeDate(year: 2026, month: 3, day: 4, hour: 9, calendar: calendar),
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            financialSessionType: sessionType,
            payments: [
                Payment(amount: 20, currencyCode: "USD", session: nil)
            ]
        )
        patient.sessions = [session]

        let snapshots = ClinicalSnapshotBuilder.buildSnapshots(
            patients: [patient],
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(snapshots[patient.id]?.hasDebt == true)
        #expect(snapshots[patient.id]?.completedSessions == 1)
        #expect(snapshots[patient.id]?.adherence == 1)
    }

    @Test("PatientClinicalSnapshot y el cache resultante son Sendable")
    func patientClinicalSnapshotAndCacheAreSendable() {
        let snapshot = PatientClinicalSnapshot(
            patientID: UUID(),
            lastSessionDate: nil,
            nextSessionDate: nil,
            sessionCount: 0,
            completedSessions: 0,
            cancelledSessions: 0,
            adherence: 0,
            daysSinceLastSession: nil,
            diagnosisSummary: nil,
            hasDebt: false
        )
        assertSendable(snapshot)

        let cache = ClinicalSnapshotBuilder.buildSnapshots(patients: [])
        assertSendable(cache)
    }

    private func assertSendable<T: Sendable>(_ value: T) {
        _ = value
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? Date()
    }
}
