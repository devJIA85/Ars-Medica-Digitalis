import Foundation
import SwiftData
import Testing
@testable import Ars_Medica_Digitalis

@MainActor
struct Ars_Medica_DigitalisTests {

    @Test("PatientViewModel.canSave valida trimming de nombre/apellido")
    func patientViewModelCanSaveWithTrimmedNames() {
        let viewModel = PatientViewModel()
        viewModel.firstName = "   "
        viewModel.lastName = "García"
        #expect(viewModel.canSave == false)

        viewModel.firstName = " Ana "
        viewModel.lastName = "   "
        #expect(viewModel.canSave == false)

        viewModel.lastName = " García "
        #expect(viewModel.canSave == true)
    }

    @Test("PatientViewModel.load copia campos principales desde Patient")
    func patientViewModelLoadCopiesFields() {
        let patient = Patient(
            firstName: "Ana",
            lastName: "García",
            gender: "femenino",
            clinicalStatus: ClinicalStatusMapping.riesgo.rawValue,
            currentMedication: "Ibuprofeno",
            smokingStatus: true
        )
        let viewModel = PatientViewModel()

        viewModel.load(from: patient)

        #expect(viewModel.firstName == "Ana")
        #expect(viewModel.lastName == "García")
        #expect(viewModel.gender == "femenino")
        #expect(viewModel.currentMedication == "Ibuprofeno")
        #expect(viewModel.clinicalStatus == ClinicalStatusMapping.riesgo.rawValue)
        #expect(viewModel.smokingStatus == true)
    }

    @Test("PatientViewModel crea historial de moneda al guardar el paciente")
    func patientViewModelCreatesCurrencyVersion() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let viewModel = PatientViewModel()
        viewModel.firstName = "Ana"
        viewModel.lastName = "García"
        viewModel.currencyCode = "USD"

        let patient = viewModel.createPatient(for: professional, in: context)
        try context.save()

        #expect(patient.currencyCode == "USD")
        #expect((patient.currencyVersions ?? []).count == 1)
        #expect(patient.currencyVersions?.first?.currencyCode == "USD")
    }

    @Test("SessionViewModel ajusta status automáticamente según fecha")
    func sessionViewModelAdjustsStatusForDate() {
        let viewModel = SessionViewModel()

        viewModel.status = SessionStatusMapping.completada.rawValue
        viewModel.sessionDate = Date().addingTimeInterval(60 * 60 * 24)
        #expect(viewModel.status == SessionStatusMapping.programada.rawValue)

        viewModel.sessionDate = Date().addingTimeInterval(-60 * 60 * 24)
        #expect(viewModel.status == SessionStatusMapping.completada.rawValue)
    }

    @Test("SessionViewModel.preloadDiagnoses importa diagnósticos vigentes")
    func sessionViewModelPreloadsActiveDiagnoses() {
        let patient = Patient(firstName: "Test", lastName: "Patient")
        let diagnosis = Diagnosis(
            icdCode: "6A70",
            icdTitle: "Single episode depressive disorder",
            icdTitleEs: "Trastorno depresivo de episodio único",
            icdURI: "http://id.who.int/icd/release/11/2024-01/mms/6A70"
        )
        patient.activeDiagnoses = [diagnosis]

        let viewModel = SessionViewModel()
        viewModel.preloadDiagnoses(from: patient)

        #expect(viewModel.selectedDiagnoses.count == 1)
        #expect(viewModel.selectedDiagnoses.first?.id == diagnosis.icdURI)
        #expect(viewModel.selectedDiagnoses.first?.theCode == diagnosis.icdCode)
    }

    @Test("SessionViewModel.createSession no borra diagnósticos vigentes sin cambios explícitos")
    func sessionViewModelCreateSessionKeepsActiveDiagnosesWhenUnchanged() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let patient = Patient(firstName: "Test", lastName: "Patient")
        context.insert(patient)

        let activeDiagnosis = Diagnosis(
            icdCode: "6A70",
            icdTitle: "Single episode depressive disorder",
            icdTitleEs: "Trastorno depresivo de episodio único",
            icdURI: "http://id.who.int/icd/release/11/2024-01/mms/6A70",
            patient: patient
        )
        context.insert(activeDiagnosis)
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.chiefComplaint = "Control"
        viewModel.status = SessionStatusMapping.programada.rawValue
        try viewModel.createSession(for: patient, in: context)
        try context.save()

        let activeURIs = Set((patient.activeDiagnoses ?? []).map(\.icdURI))
        #expect(activeURIs == [activeDiagnosis.icdURI])
    }

    @Test("SessionViewModel.createSession permite limpiar vigentes si el usuario los quita")
    func sessionViewModelCreateSessionCanClearActiveDiagnosesOnExplicitRemove() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let patient = Patient(firstName: "Test", lastName: "Patient")
        context.insert(patient)

        let activeDiagnosis = Diagnosis(
            icdCode: "6A70",
            icdTitle: "Single episode depressive disorder",
            icdTitleEs: "Trastorno depresivo de episodio único",
            icdURI: "http://id.who.int/icd/release/11/2024-01/mms/6A70",
            patient: patient
        )
        context.insert(activeDiagnosis)
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.chiefComplaint = "Control"
        viewModel.status = SessionStatusMapping.programada.rawValue
        viewModel.preloadDiagnoses(from: patient)
        if let preloaded = viewModel.selectedDiagnoses.first {
            viewModel.removeDiagnosis(preloaded)
        }

        try viewModel.createSession(for: patient, in: context)
        try context.save()

        #expect((patient.activeDiagnoses ?? []).isEmpty)
    }

    @Test("SessionViewModel.update no altera vigentes si no se editaron diagnósticos")
    func sessionViewModelUpdateKeepsActiveDiagnosesWhenDiagnosesUntouched() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let patient = Patient(firstName: "Test", lastName: "Patient")
        context.insert(patient)

        let activeDiagnosis = Diagnosis(
            icdCode: "6A70",
            icdTitle: "Single episode depressive disorder",
            icdTitleEs: "Trastorno depresivo de episodio único",
            icdURI: "http://id.who.int/icd/release/11/2024-01/mms/6A70",
            patient: patient
        )
        context.insert(activeDiagnosis)

        let session = Session(
            chiefComplaint: "Primera consulta",
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(session)

        let sessionDiagnosis = Diagnosis(
            icdCode: "6A71",
            icdTitle: "Another diagnosis",
            icdTitleEs: "Otro diagnóstico",
            icdURI: "http://id.who.int/icd/release/11/2024-01/mms/6A71",
            session: session
        )
        context.insert(sessionDiagnosis)
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.load(from: session)
        viewModel.notes = "Nota actualizada"
        try viewModel.update(session, in: context)
        try context.save()

        let activeURIs = Set((patient.activeDiagnoses ?? []).map(\.icdURI))
        #expect(activeURIs == [activeDiagnosis.icdURI])
    }

    @Test("DashboardViewModel calcula KPIs base de sesiones")
    func dashboardViewModelComputesKPIs() {
        let now = Date()
        let patientA = Patient(firstName: "A", lastName: "One")
        patientA.sessions = [
            Session(sessionDate: now, durationMinutes: 50, status: SessionStatusMapping.completada.rawValue),
            Session(sessionDate: now, durationMinutes: 30, status: SessionStatusMapping.cancelada.rawValue),
        ]

        let patientB = Patient(firstName: "B", lastName: "Two")
        patientB.sessions = [
            Session(sessionDate: now, durationMinutes: 40, status: SessionStatusMapping.programada.rawValue),
        ]

        let viewModel = DashboardViewModel()
        viewModel.loadStatistics(from: [patientA, patientB])

        #expect(viewModel.totalPatients == 2)
        #expect(viewModel.sessionsThisMonth == 3)
        #expect(viewModel.averageDurationMinutes == 50)
        #expect(viewModel.completionRate == 50)
    }

    @Test("SessionViewModel.completeSession congela snapshots financieros")
    func sessionViewModelCompleteSessionFreezesFinancialSnapshots() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Ana",
            lastName: "Paciente",
            currencyCode: "USD",
            professional: professional
        )
        context.insert(patient)

        let currencyVersion = PatientCurrencyVersion(
            currencyCode: "USD",
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            patient: patient
        )
        context.insert(currencyVersion)

        let sessionType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            price: 90,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(priceVersion)

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: sessionType
        )
        context.insert(session)
        try context.save()

        let viewModel = SessionViewModel()
        let draft = viewModel.preparePaymentFlow(for: session)
        try viewModel.completeSession(session, in: context, paymentIntent: .none)

        #expect(draft.sessionID == session.id)
        #expect(draft.amountDue == 90)
        #expect(draft.currencyCode == "USD")
        #expect(session.status == SessionStatusMapping.completada.rawValue)
        #expect(session.finalPriceSnapshot == 90)
        #expect(session.finalCurrencySnapshot == "USD")
    }

    @Test("SessionViewModel prepara un borrador bloqueado si falta configuración financiera")
    func sessionViewModelPreparePaymentFlowFlagsMissingConfiguration() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(firstName: "Ana", lastName: "Paciente", professional: professional)
        context.insert(patient)

        let session = Session(
            sessionDate: Date(),
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(session)
        try context.save()

        let viewModel = SessionViewModel()
        let draft = viewModel.preparePaymentFlow(for: session)

        #expect(draft.isFinanciallyConfigured == false)
        #expect(draft.configurationIssue == .missingFinancialSessionType)
        #expect(draft.amountDue == 0)
        #expect(draft.currencyCode.isEmpty)
    }

    @Test("SessionViewModel resuelve preview financiero dinámico para el formulario")
    func sessionViewModelPricingPreviewResolvesAmountAndCurrency() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Ana",
            lastName: "Paciente",
            currencyCode: "ARS",
            professional: professional
        )
        context.insert(patient)

        let currencyVersion = PatientCurrencyVersion(
            currencyCode: "ARS",
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            patient: patient
        )
        context.insert(currencyVersion)

        let sessionType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            price: 25000,
            currencyCode: "ARS",
            sessionCatalogType: sessionType
        )
        context.insert(priceVersion)
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.sessionDate = now
        viewModel.financialSessionTypeID = sessionType.id

        let preview = viewModel.pricingPreview(for: patient, in: context)

        #expect(preview.configurationIssue == nil)
        #expect(preview.currencyCode == "ARS")
        #expect(preview.amount == 25000)
    }

    @Test("CalendarViewModel navega entre meses")
    func calendarViewModelMonthNavigation() {
        let viewModel = CalendarViewModel()
        let calendar = Calendar.current
        let initial = date(year: 2026, month: 1, day: 15)
        viewModel.displayedMonth = initial

        viewModel.goToNextMonth()
        let next = calendar.dateComponents([.year, .month], from: viewModel.displayedMonth)
        #expect(next.year == 2026)
        #expect(next.month == 2)

        viewModel.goToPreviousMonth()
        let back = calendar.dateComponents([.year, .month], from: viewModel.displayedMonth)
        #expect(back.year == 2026)
        #expect(back.month == 1)
    }

    @Test("CalendarViewModel.calendarDays refleja cantidad de días del mes")
    func calendarViewModelCalendarDaysCount() {
        let viewModel = CalendarViewModel()
        viewModel.displayedMonth = date(year: 2026, month: 2, day: 1) // Febrero 2026 = 28 días

        let dayCount = viewModel.calendarDays().compactMap { $0 }.count
        #expect(dayCount == 28)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date()
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Professional.self,
            PricingAdjustmentPolicy.self,
            Patient.self,
            Session.self,
            SessionCatalogType.self,
            SessionTypePriceVersion.self,
            PatientCurrencyVersion.self,
            PatientSessionDefaultPrice.self,
            Payment.self,
            Diagnosis.self,
            Attachment.self,
            PriorTreatment.self,
            Hospitalization.self,
            AnthropometricRecord.self,
            ICD11Entry.self,
            Medication.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
