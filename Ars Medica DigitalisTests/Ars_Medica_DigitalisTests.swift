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

    @Test("Patient.hasOutstandingDebt solo marca deuda en sesiones completadas con saldo")
    func patientHasOutstandingDebtOnlyForCompletedSessionsWithDebt() {
        let patient = Patient(firstName: "Ana", lastName: "García")

        let completedSession = Session(
            sessionDate: Date(),
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "ARS"
        )

        let scheduledSession = Session(
            sessionDate: Date(),
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            finalPriceSnapshot: 200,
            finalCurrencySnapshot: "ARS"
        )

        patient.sessions = [completedSession, scheduledSession]

        #expect(patient.hasOutstandingDebt == true)

        let payment = Payment(
            amount: 100,
            currencyCode: "ARS",
            paidAt: Date(),
            session: completedSession
        )
        completedSession.payments = [payment]

        #expect(patient.hasOutstandingDebt == false)
    }

    @Test("PatientRow usa el título legible del diagnóstico principal")
    func patientRowUsesPrincipalDiagnosisDisplayTitle() {
        let principal = Diagnosis(
            icdCode: "QE84",
            icdTitle: "Unused title",
            icdTitleEs: "Reacción aguda al estrés",
            diagnosisType: .principal
        )
        let secondary = Diagnosis(
            icdCode: "6D10.Z",
            icdTitleEs: "Ansiedad no especificada",
            diagnosisType: .secundario
        )
        let patient = Patient(firstName: "Ana", lastName: "García")
        patient.activeDiagnoses = [secondary, principal]

        let summary = PatientRowDiagnosisSummaryBuilder.primarySummary(for: patient)

        #expect(summary == "Reacción aguda al estrés +1")
    }

    @Test("PatientRow cae al primer diagnóstico cuando no existe uno principal")
    func patientRowFallsBackToFirstDiagnosisWhenNoPrincipalExists() {
        let first = Diagnosis(
            icdCode: "6B40",
            icdTitleEs: "Trastorno de estrés postraumático",
            diagnosisType: .secundario
        )
        let second = Diagnosis(
            icdCode: "6E40.4",
            icdTitleEs: "Respuesta fisiológica relacionada con el estrés",
            diagnosisType: .secundario
        )

        let summary = PatientRowDiagnosisSummaryBuilder.summary(from: [first, second])

        #expect(summary == "Trastorno de estrés postraumático +1")
    }

    @Test("PatientRow agrega el contador extra cuando hay múltiples diagnósticos")
    func patientRowAddsExtraCountWhenMultipleDiagnosesExist() {
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
        let differential = Diagnosis(
            icdCode: "6B40",
            icdTitleEs: "Trastorno de estrés postraumático",
            diagnosisType: .diferencial
        )

        let summary = PatientRowDiagnosisSummaryBuilder.summary(
            from: [secondary, principal, differential]
        )

        #expect(summary == "Reacción aguda al estrés +2")
    }

    @Test("PatientRow abrevia el diagnóstico usando la primera cláusula útil")
    func patientRowUsesFirstMeaningfulClauseForLongDiagnosis() {
        let principal = Diagnosis(
            icdCode: "6B40",
            icdTitleEs: "Estrés, no clasificado en otra parte",
            diagnosisType: .principal
        )

        let summary = PatientRowDiagnosisSummaryBuilder.summary(from: [principal])

        #expect(summary == "Estrés")
    }

    @Test("PatientRow abrevia diagnósticos muy largos por palabras")
    func patientRowTruncatesVeryLongDiagnosisByWords() {
        let principal = Diagnosis(
            icdCode: "6E40.4",
            icdTitleEs: "Respuesta fisiológica relacionada con el estrés que afecta a enfermedades o trastornos",
            diagnosisType: .principal
        )

        let summary = PatientRowDiagnosisSummaryBuilder.summary(from: [principal])

        #expect(summary == "Respuesta fisiológica relacionada con el…")
    }

    @Test("PatientRow usa la última sesión completada si no hay diagnósticos activos")
    func patientRowFallsBackToLatestCompletedSessionDiagnoses() {
        let patient = Patient(firstName: "Ana", lastName: "García")

        let olderDiagnosis = Diagnosis(
            icdCode: "6D10.Z",
            icdTitleEs: "Ansiedad no especificada",
            diagnosisType: .principal
        )
        let latestDiagnosis = Diagnosis(
            icdCode: "QE84",
            icdTitleEs: "Reacción aguda al estrés",
            diagnosisType: .principal
        )

        let olderSession = Session(
            sessionDate: ISO8601DateFormatter().date(from: "2026-03-01T10:00:00Z")!,
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            diagnoses: [olderDiagnosis]
        )
        let latestSession = Session(
            sessionDate: ISO8601DateFormatter().date(from: "2026-03-03T10:00:00Z")!,
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            diagnoses: [latestDiagnosis]
        )
        patient.sessions = [olderSession, latestSession]

        let summary = PatientRowDiagnosisSummaryBuilder.primarySummary(for: patient)

        #expect(summary == "Reacción aguda al estrés")
    }

    @Test("PatientRow oculta el badge clínico si no hay diagnósticos válidos")
    func patientRowHidesDiagnosisBadgeWhenNoDiagnosesExist() {
        let patient = Patient(firstName: "Ana", lastName: "García")
        patient.activeDiagnoses = []
        patient.sessions = []

        let summary = PatientRowDiagnosisSummaryBuilder.primarySummary(for: patient)

        #expect(summary == nil)
    }

    @Test("Date.defaultSessionStartDate usa una hora neutral cuando la fecha viene solo con día")
    func defaultSessionStartDateUsesNeutralHourForDayOnlyDates() {
        let calendar = Calendar(identifier: .gregorian)
        let dateOnly = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 3, hour: 0, minute: 0)
        )!

        let resolved = dateOnly.defaultSessionStartDate(
            fallbackHour: 9,
            fallbackMinute: 0,
            calendar: calendar
        )
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: resolved)

        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 3)
        #expect(components.hour == 9)
        #expect(components.minute == 0)
    }

    @Test("Date.defaultSessionStartDate respeta una hora explícita si ya viene en la fecha")
    func defaultSessionStartDateKeepsExplicitTime() {
        let calendar = Calendar(identifier: .gregorian)
        let explicitDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 3, hour: 8, minute: 12)
        )!

        let resolved = explicitDate.defaultSessionStartDate(
            fallbackHour: 9,
            fallbackMinute: 0,
            calendar: calendar
        )
        let components = calendar.dateComponents([.hour, .minute], from: resolved)

        #expect(components.hour == 8)
        #expect(components.minute == 10)
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
        #expect(patient.currencyVersions.count == 1)
        #expect(patient.currencyVersions.first?.currencyCode == "USD")
    }

    @Test("PatientViewModel usa la moneda default del profesional en pacientes nuevos")
    func patientViewModelUsesProfessionalDefaultCurrency() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let professional = Professional(
            fullName: "Profesional",
            defaultPatientCurrencyCode: "ARS"
        )
        context.insert(professional)

        let viewModel = PatientViewModel()
        viewModel.firstName = "Ana"
        viewModel.lastName = "García"

        let patient = viewModel.createPatient(for: professional, in: context)
        try context.save()

        #expect(viewModel.currencyCode == "ARS")
        #expect(patient.currencyCode == "ARS")
        #expect(patient.currencyVersions.first?.currencyCode == "ARS")
    }

    @Test("PatientViewModel genera HC para altas con valor vacío o espacios")
    func patientViewModelGeneratesMedicalRecordNumberForBlankInput() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let viewModel = PatientViewModel()
        viewModel.firstName = "Ana"
        viewModel.lastName = "García"
        viewModel.medicalRecordNumber = "   "

        let patient = viewModel.createPatient(for: professional, in: context)

        #expect(patient.medicalRecordNumber.hasPrefix("HC-"))
        #expect(patient.medicalRecordNumber.count == 11)
    }

    @Test("PatientViewModel repara HC faltante al editar un paciente existente")
    func patientViewModelRepairsMissingMedicalRecordNumberOnUpdate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let patient = Patient(
            firstName: "Ana",
            lastName: "García",
            medicalRecordNumber: "   "
        )
        context.insert(patient)

        let viewModel = PatientViewModel()
        viewModel.load(from: patient)
        viewModel.occupation = "Docente"
        viewModel.update(patient, in: context)

        #expect(patient.medicalRecordNumber.hasPrefix("HC-"))
        #expect(patient.medicalRecordNumber.count == 11)
        #expect(patient.occupation == "Docente")
    }

    @Test("PatientMedicalRecordNumberService backfillea HC faltantes y normaliza espacios")
    func patientMedicalRecordNumberServiceRepairsExistingPatients() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let missing = Patient(firstName: "Ana", lastName: "García", medicalRecordNumber: "")
        let spaced = Patient(firstName: "Luis", lastName: "Pérez", medicalRecordNumber: "  HC-1234  ")
        let valid = Patient(firstName: "Mora", lastName: "Suárez", medicalRecordNumber: "HC-EXISTING")

        context.insert(missing)
        context.insert(spaced)
        context.insert(valid)

        let result = try PatientMedicalRecordNumberService().repairMissingRecordNumbers(in: context)

        #expect(result.generatedCount == 1)
        #expect(result.normalizedCount == 1)
        #expect(result.skippedCount == 1)
        #expect(missing.medicalRecordNumber.hasPrefix("HC-"))
        #expect(missing.medicalRecordNumber.count == 11)
        #expect(spaced.medicalRecordNumber == "HC-1234")
        #expect(valid.medicalRecordNumber == "HC-EXISTING")
    }

    @Test("El primer honorario queda sugerido por defecto para nuevas sesiones")
    func firstHonorariumBecomesSuggestedFinancialType() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let createViewModel = HonorariumCreateViewModel()
        createViewModel.name = "Individual"
        createViewModel.currencyCode = "ARS"
        createViewModel.price = 25000

        try createViewModel.save(for: professional, in: context)

        let secondCreateViewModel = HonorariumCreateViewModel()
        secondCreateViewModel.name = "Pareja"
        secondCreateViewModel.currencyCode = "ARS"
        secondCreateViewModel.price = 40000

        try secondCreateViewModel.save(for: professional, in: context)
        try context.save()

        let suggestedID = professional.defaultFinancialSessionTypeID
        let firstTypeID = professional.sessionCatalogTypes
            .sorted { $0.sortOrder < $1.sortOrder }
            .first?.id

        #expect(suggestedID == firstTypeID)
    }

    @Test("Crear un honorario en otra moneda reutiliza el mismo tipo facturable")
    func honorariumCreateViewModelReusesExistingSessionTypeForNewCurrency() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let arsViewModel = HonorariumCreateViewModel()
        arsViewModel.name = "Sesión Psi"
        arsViewModel.currencyCode = "ARS"
        arsViewModel.price = 55000
        try arsViewModel.save(for: professional, in: context)

        let usdViewModel = HonorariumCreateViewModel()
        usdViewModel.name = "Sesion Psi"
        usdViewModel.currencyCode = "USD"
        usdViewModel.price = 60
        try usdViewModel.save(for: professional, in: context)

        let sessionTypes = professional.sessionCatalogTypes
        #expect(sessionTypes.count == 1)
        #expect(sessionTypes.first?.priceVersions.count == 2)
    }

    @Test("Crear otra moneda reutiliza el tipo aunque el profesional se recargue desde SwiftData")
    func honorariumCreateViewModelReusesExistingSessionTypeForReloadedProfessional() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let arsViewModel = HonorariumCreateViewModel()
        arsViewModel.name = "Sesión Psi"
        arsViewModel.currencyCode = "ARS"
        arsViewModel.price = 55000
        try arsViewModel.save(for: professional, in: context)

        let freshContext = ModelContext(container)
        let professionalID = professional.id
        let professionalDescriptor = FetchDescriptor<Professional>(
            predicate: #Predicate<Professional> { candidate in
                candidate.id == professionalID
            }
        )
        let reloadedProfessional = try #require(freshContext.fetch(professionalDescriptor).first)

        let usdViewModel = HonorariumCreateViewModel()
        usdViewModel.name = "Sesion Psi"
        usdViewModel.currencyCode = "USD"
        usdViewModel.price = 60
        try usdViewModel.save(for: reloadedProfessional, in: freshContext)

        let sessionTypeDescriptor = FetchDescriptor<SessionCatalogType>(
            predicate: #Predicate<SessionCatalogType> { sessionType in
                sessionType.professional?.id == professionalID
            }
        )
        let sessionTypes = try freshContext.fetch(sessionTypeDescriptor)

        #expect(sessionTypes.count == 1)
        #expect(sessionTypes.first?.priceVersions.count == 2)
    }

    @Test("HonorariosSuggestedTypeRules usa la preferencia activa del profesional")
    func honorariosSuggestedTypeRulesUsesExplicitActiveDefault() {
        let firstType = SessionCatalogType(name: "Individual")
        let secondType = SessionCatalogType(name: "Pareja", sortOrder: 1)

        let snapshots = [
            SessionTypeBusinessSnapshot(
                sessionType: firstType,
                currentPrice: 25000,
                currentCurrencyCode: "ARS",
                effectiveFrom: nil,
                lastPriceVersion: nil,
                monthsSinceLastUpdate: 0,
                ipcAccumulated: 0,
                shouldSuggestUpdate: false,
                suggestedPrice: nil
            ),
            SessionTypeBusinessSnapshot(
                sessionType: secondType,
                currentPrice: 40000,
                currentCurrencyCode: "ARS",
                effectiveFrom: nil,
                lastPriceVersion: nil,
                monthsSinceLastUpdate: 0,
                ipcAccumulated: 0,
                shouldSuggestUpdate: false,
                suggestedPrice: nil
            ),
        ]

        let resolvedID = HonorariosSuggestedTypeRules.resolvedDefaultSessionTypeID(
            defaultSessionTypeID: secondType.id,
            activeSnapshots: snapshots
        )

        #expect(resolvedID == secondType.id)
    }

    @Test("HonorariosSuggestedTypeRules cae al primer tipo activo si la preferencia no sirve")
    func honorariosSuggestedTypeRulesFallsBackToFirstActiveType() {
        let inactiveType = SessionCatalogType(name: "Viejo", isActive: false)
        let firstActiveType = SessionCatalogType(name: "Individual")
        let secondActiveType = SessionCatalogType(name: "Pareja", sortOrder: 1)

        let snapshots = [
            SessionTypeBusinessSnapshot(
                sessionType: inactiveType,
                currentPrice: 15000,
                currentCurrencyCode: "ARS",
                effectiveFrom: nil,
                lastPriceVersion: nil,
                monthsSinceLastUpdate: 0,
                ipcAccumulated: 0,
                shouldSuggestUpdate: false,
                suggestedPrice: nil
            ),
            SessionTypeBusinessSnapshot(
                sessionType: firstActiveType,
                currentPrice: 25000,
                currentCurrencyCode: "ARS",
                effectiveFrom: nil,
                lastPriceVersion: nil,
                monthsSinceLastUpdate: 0,
                ipcAccumulated: 0,
                shouldSuggestUpdate: false,
                suggestedPrice: nil
            ),
            SessionTypeBusinessSnapshot(
                sessionType: secondActiveType,
                currentPrice: 40000,
                currentCurrencyCode: "ARS",
                effectiveFrom: nil,
                lastPriceVersion: nil,
                monthsSinceLastUpdate: 0,
                ipcAccumulated: 0,
                shouldSuggestUpdate: false,
                suggestedPrice: nil
            ),
        ]

        let activeSnapshots = HonorariosSuggestedTypeRules.activeSnapshots(
            from: snapshots
        )
        let resolvedID = HonorariosSuggestedTypeRules.resolvedDefaultSessionTypeID(
            defaultSessionTypeID: UUID(),
            activeSnapshots: activeSnapshots
        )

        #expect(activeSnapshots.count == 2)
        #expect(activeSnapshots.contains { $0.sessionType.id == inactiveType.id } == false)
        #expect(resolvedID == firstActiveType.id)
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

        let activeURIs = Set(patient.activeDiagnoses.map(\.icdURI))
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

        #expect(patient.activeDiagnoses.isEmpty)
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

        let activeURIs = Set(patient.activeDiagnoses.map(\.icdURI))
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

    @Test("SessionPricingService usa un tipo homónimo si la moneda quedó en un duplicado")
    func sessionPricingServiceUsesSiblingSessionTypeWhenCurrencyLivesOnDuplicate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Mari",
            lastName: "Kita",
            currencyCode: "USD",
            professional: professional
        )
        context.insert(patient)

        let selectedType = SessionCatalogType(
            name: "Sesión Psi",
            professional: professional
        )
        let duplicatedType = SessionCatalogType(
            name: "Sesion Psi",
            sortOrder: 1,
            professional: professional
        )
        context.insert(selectedType)
        context.insert(duplicatedType)

        let arsVersion = SessionTypePriceVersion(
            effectiveFrom: Date(),
            price: 55000,
            currencyCode: "ARS",
            sessionCatalogType: selectedType
        )
        let usdVersion = SessionTypePriceVersion(
            effectiveFrom: Date(),
            price: 60,
            currencyCode: "USD",
            sessionCatalogType: duplicatedType
        )
        context.insert(arsVersion)
        context.insert(usdVersion)

        let session = Session(
            sessionDate: Date(),
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: selectedType
        )
        context.insert(session)
        try context.save()

        #expect(session.effectiveCurrency == "USD")
        #expect(session.effectivePrice == 60)
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

    @Test("SessionViewModel resuelve preview en USD con paciente recargado y tipo sugerido")
    func sessionViewModelPricingPreviewResolvesSuggestedUSDTypeForReloadedPatient() throws {
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

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
                patient: patient
            )
        )

        let sessionType = SessionCatalogType(
            name: "Sesión Psi",
            professional: professional
        )
        context.insert(sessionType)
        professional.defaultFinancialSessionTypeID = sessionType.id

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
                price: 60,
                currencyCode: "USD",
                sessionCatalogType: sessionType
            )
        )
        try context.save()

        let freshContext = ModelContext(container)
        let patientID = patient.id
        let patientDescriptor = FetchDescriptor<Patient>(
            predicate: #Predicate<Patient> { candidate in
                candidate.id == patientID
            }
        )
        let reloadedPatient = try #require(freshContext.fetch(patientDescriptor).first)

        let viewModel = SessionViewModel()
        let preview = viewModel.pricingPreview(for: reloadedPatient, in: freshContext)

        #expect(preview.configurationIssue == nil)
        #expect(preview.currencyCode == "USD")
        #expect(preview.amount == 60)
    }

    @Test("SessionViewModel.pricingPreview no inserta sesiones fantasma")
    func sessionViewModelPricingPreviewDoesNotInsertSessions() throws {
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

        let sessionType = SessionCatalogType(
            name: "Sesión Psi",
            professional: professional
        )
        context.insert(sessionType)
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 45000,
                currencyCode: "ARS",
                sessionCatalogType: sessionType
            )
        )
        try context.save()

        let countBefore = try context.fetchCount(FetchDescriptor<Session>())

        let viewModel = SessionViewModel()
        viewModel.sessionDate = now
        viewModel.financialSessionTypeID = sessionType.id
        let preview = viewModel.pricingPreview(for: patient, in: context)

        let countAfter = try context.fetchCount(FetchDescriptor<Session>())

        #expect(preview.amount == 45000)
        #expect(countAfter == countBefore)
    }

    @Test("SessionViewModel.availableFinancialSessionTypes no inserta sesiones fantasma")
    func sessionViewModelAvailableFinancialSessionTypesDoesNotInsertSessions() throws {
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
        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let arsType = SessionCatalogType(
            name: "Pesos",
            professional: professional
        )
        let usdType = SessionCatalogType(
            name: "Dólares",
            sortOrder: 1,
            professional: professional
        )
        context.insert(arsType)
        context.insert(usdType)
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 45000,
                currencyCode: "ARS",
                sessionCatalogType: arsType
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 35,
                currencyCode: "USD",
                sessionCatalogType: usdType
            )
        )
        try context.save()

        let countBefore = try context.fetchCount(FetchDescriptor<Session>())
        let viewModel = SessionViewModel()

        let compatibleTypes = viewModel.availableFinancialSessionTypes(for: patient, in: context)
        let countAfter = try context.fetchCount(FetchDescriptor<Session>())

        #expect(compatibleTypes.map(\.id) == [usdType.id])
        #expect(countAfter == countBefore)
    }

    @Test("SessionViewModel.createAndCompleteSession crea una sola sesión y un solo pago")
    func sessionViewModelCreateAndCompleteSessionCreatesExactlyOneSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Diana",
            lastName: "Prince",
            currencyCode: "USD",
            professional: professional
        )
        context.insert(patient)
        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let sessionType = SessionCatalogType(
            name: "Dólares",
            professional: professional
        )
        context.insert(sessionType)
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 35,
                currencyCode: "USD",
                sessionCatalogType: sessionType
            )
        )
        try context.save()

        let snapshot = SessionFormSnapshot(
            sessionDate: now,
            sessionType: SessionTypeMapping.presencial.rawValue,
            durationMinutes: 50,
            chiefComplaint: "Control",
            notes: "",
            treatmentPlan: "",
            status: SessionStatusMapping.completada.rawValue,
            financialSessionTypeID: sessionType.id,
            isCourtesy: false,
            selectedDiagnoses: []
        )

        let viewModel = SessionViewModel()
        _ = try viewModel.createAndCompleteSession(
            from: snapshot,
            for: patient,
            in: context,
            paymentIntent: .full
        )

        #expect(try context.fetchCount(FetchDescriptor<Session>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Payment>()) == 1)
    }

    @Test("SessionViewModel.updateAndCompleteSession no crea sesiones extra")
    func sessionViewModelUpdateAndCompleteSessionDoesNotCreateExtraSession() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Diana",
            lastName: "Prince",
            currencyCode: "USD",
            professional: professional
        )
        context.insert(patient)
        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let sessionType = SessionCatalogType(
            name: "Dólares",
            professional: professional
        )
        context.insert(sessionType)
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 35,
                currencyCode: "USD",
                sessionCatalogType: sessionType
            )
        )

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(session)
        try context.save()

        let snapshot = SessionFormSnapshot(
            sessionDate: now,
            sessionType: SessionTypeMapping.presencial.rawValue,
            durationMinutes: 50,
            chiefComplaint: "Control",
            notes: "",
            treatmentPlan: "",
            status: SessionStatusMapping.completada.rawValue,
            financialSessionTypeID: sessionType.id,
            isCourtesy: false,
            selectedDiagnoses: []
        )

        let viewModel = SessionViewModel()
        _ = try viewModel.updateAndCompleteSession(
            session,
            from: snapshot,
            in: context,
            paymentIntent: .none
        )

        #expect(try context.fetchCount(FetchDescriptor<Session>()) == 1)
    }

    @Test("SessionPhantomRepairService elimina borradores fantasma vacíos")
    func sessionPhantomRepairServiceRemovesPhantomSessions() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let patient = Patient(firstName: "Ana", lastName: "Paciente")
        context.insert(patient)

        let phantom = Session(
            sessionDate: Date(),
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        let validSession = Session(
            sessionDate: Date(),
            chiefComplaint: "Consulta válida",
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(phantom)
        context.insert(validSession)
        try context.save()

        let result = try await SessionPhantomRepairService().repairIfNeeded(in: context)

        #expect(result.removedCount == 1)
        #expect(try context.fetchCount(FetchDescriptor<Session>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Session>()).first?.chiefComplaint == "Consulta válida")
    }

    @Test("SessionPhantomRepairService es idempotente")
    func sessionPhantomRepairServiceIsIdempotent() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let patient = Patient(firstName: "Ana", lastName: "Paciente")
        context.insert(patient)
        context.insert(
            Session(
                sessionDate: Date(),
                status: SessionStatusMapping.programada.rawValue,
                patient: patient
            )
        )
        try context.save()

        let firstResult = try await SessionPhantomRepairService().repairIfNeeded(in: context)
        let secondResult = try await SessionPhantomRepairService().repairIfNeeded(in: context)

        #expect(firstResult.removedCount == 1)
        #expect(secondResult.removedCount == 0)
        #expect(try context.fetchCount(FetchDescriptor<Session>()) == 0)
    }

    @Test("SessionViewModel sugiere un tipo compatible con la moneda del paciente")
    func sessionViewModelSuggestsCurrencyCompatibleFinancialType() throws {
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

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let arsType = SessionCatalogType(
            name: "Sesión Psi",
            professional: professional
        )
        let usdType = SessionCatalogType(
            name: "Dólares",
            sortOrder: 1,
            professional: professional
        )
        context.insert(arsType)
        context.insert(usdType)
        professional.defaultFinancialSessionTypeID = arsType.id

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 55000,
                currencyCode: "ARS",
                sessionCatalogType: arsType
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 35,
                currencyCode: "USD",
                sessionCatalogType: usdType
            )
        )
        try context.save()

        let viewModel = SessionViewModel()
        let suggestedID = viewModel.suggestedFinancialSessionTypeID(for: patient)
        let visibleTypes = viewModel.availableFinancialSessionTypes(for: patient, in: context)

        #expect(suggestedID == usdType.id)
        #expect(visibleTypes.map(\.id) == [usdType.id])
    }

    @Test("SessionViewModel.createSession completa en USD usando el tipo seleccionado")
    func sessionViewModelCreateSessionCompletesWithSelectedUSDType() throws {
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

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let arsType = SessionCatalogType(
            name: "Sesión Psi",
            professional: professional
        )
        let usdType = SessionCatalogType(
            name: "Dólares",
            sortOrder: 1,
            professional: professional
        )
        context.insert(arsType)
        context.insert(usdType)
        professional.defaultFinancialSessionTypeID = arsType.id

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 55000,
                currencyCode: "ARS",
                sessionCatalogType: arsType
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 35,
                currencyCode: "USD",
                sessionCatalogType: usdType
            )
        )
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.sessionDate = now
        viewModel.status = SessionStatusMapping.completada.rawValue
        viewModel.chiefComplaint = "Seguimiento"
        viewModel.financialSessionTypeID = usdType.id

        let session = try viewModel.createSession(for: patient, in: context)

        #expect(session.financialSessionType?.id == usdType.id)
        #expect(session.finalCurrencySnapshot == "USD")
        #expect(session.finalPriceSnapshot == 35)
    }

    @Test("SessionViewModel.update completa en USD usando el tipo seleccionado")
    func sessionViewModelUpdateCompletesWithSelectedUSDType() throws {
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

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let arsType = SessionCatalogType(
            name: "Sesión Psi",
            professional: professional
        )
        let usdType = SessionCatalogType(
            name: "Dólares",
            sortOrder: 1,
            professional: professional
        )
        context.insert(arsType)
        context.insert(usdType)
        professional.defaultFinancialSessionTypeID = arsType.id

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 55000,
                currencyCode: "ARS",
                sessionCatalogType: arsType
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 35,
                currencyCode: "USD",
                sessionCatalogType: usdType
            )
        )

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(session)
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.load(from: session)
        viewModel.status = SessionStatusMapping.completada.rawValue
        viewModel.chiefComplaint = "Seguimiento"
        viewModel.financialSessionTypeID = usdType.id

        let updatedSession = try viewModel.update(session, in: context)

        #expect(updatedSession.financialSessionType?.id == usdType.id)
        #expect(updatedSession.finalCurrencySnapshot == "USD")
        #expect(updatedSession.finalPriceSnapshot == 35)
    }

    @Test("SessionViewModel usa el único tipo facturable activo aunque la UI no lo haya seleccionado")
    func sessionViewModelPricingPreviewUsesImplicitSingleFinancialType() throws {
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
            effectiveFrom: now.addingTimeInterval(-60 * 60),
            patient: patient
        )
        context.insert(currencyVersion)

        let sessionType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60),
            price: 30000,
            currencyCode: "ARS",
            sessionCatalogType: sessionType
        )
        context.insert(priceVersion)
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.sessionDate = now

        let preview = viewModel.pricingPreview(for: patient, in: context)

        #expect(preview.configurationIssue == nil)
        #expect(preview.currencyCode == "ARS")
        #expect(preview.amount == 30000)
    }

    @Test("SessionViewModel usa el tipo sugerido del profesional cuando hay múltiples honorarios")
    func sessionViewModelUsesProfessionalSuggestedFinancialType() throws {
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
            effectiveFrom: now.addingTimeInterval(-60 * 60),
            patient: patient
        )
        context.insert(currencyVersion)

        let individualType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(individualType)

        let parejaType = SessionCatalogType(
            name: "Pareja",
            sortOrder: 1,
            professional: professional
        )
        context.insert(parejaType)

        professional.defaultFinancialSessionTypeID = parejaType.id

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 25000,
                currencyCode: "ARS",
                sessionCatalogType: individualType
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 40000,
                currencyCode: "ARS",
                sessionCatalogType: parejaType
            )
        )
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.sessionDate = now

        let preview = viewModel.pricingPreview(for: patient, in: context)

        #expect(viewModel.suggestedFinancialSessionTypeID(for: patient) == parejaType.id)
        #expect(preview.configurationIssue == nil)
        #expect(preview.amount == 40000)
        #expect(preview.currencyCode == "ARS")
    }

    @Test("SessionViewModel muestra en UI el tipo sugerido mientras no haya selección manual")
    func sessionViewModelDisplaysSuggestedFinancialTypeWhenSelectionIsNil() throws {
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

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "ARS",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let individualType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        let parejaType = SessionCatalogType(
            name: "Pareja",
            sortOrder: 1,
            professional: professional
        )
        context.insert(individualType)
        context.insert(parejaType)

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 25000,
                currencyCode: "ARS",
                sessionCatalogType: individualType
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 40000,
                currencyCode: "ARS",
                sessionCatalogType: parejaType
            )
        )

        professional.defaultFinancialSessionTypeID = parejaType.id
        try context.save()

        let viewModel = SessionViewModel()
        viewModel.sessionDate = now

        #expect(viewModel.financialSessionTypeID == nil)
        #expect(viewModel.displayedFinancialSessionTypeID(for: patient) == parejaType.id)

        viewModel.financialSessionTypeID = individualType.id

        #expect(viewModel.displayedFinancialSessionTypeID(for: patient) == individualType.id)
    }

    @Test("SessionViewModel prepara el cierre usando el tipo sugerido aunque la sesión todavía no lo tenga guardado")
    func sessionViewModelPreparePaymentFlowUsesSuggestedTypeForExistingSession() throws {
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

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "ARS",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let sessionType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)
        professional.defaultFinancialSessionTypeID = sessionType.id

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 55000,
                currencyCode: "ARS",
                sessionCatalogType: sessionType
            )
        )

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(session)
        try context.save()

        let viewModel = SessionViewModel()
        let draft = viewModel.preparePaymentFlow(for: session)

        #expect(draft.configurationIssue == nil)
        #expect(draft.currencyCode == "ARS")
        #expect(draft.amountDue == 55000)
        #expect(viewModel.effectiveFinancialSessionTypeName(for: session) == "Individual")
    }

    @Test("SessionViewModel persiste el tipo sugerido al completar una sesión existente")
    func sessionViewModelCompleteSessionPersistsSuggestedFinancialType() throws {
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

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "ARS",
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                patient: patient
            )
        )

        let sessionType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)
        professional.defaultFinancialSessionTypeID = sessionType.id

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: now.addingTimeInterval(-60 * 60),
                price: 55000,
                currencyCode: "ARS",
                sessionCatalogType: sessionType
            )
        )

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(session)
        try context.save()

        let viewModel = SessionViewModel()
        try viewModel.completeSession(session, in: context, paymentIntent: .none)

        #expect(session.financialSessionType?.id == sessionType.id)
        #expect(session.finalCurrencySnapshot == "ARS")
        #expect(session.finalPriceSnapshot == 55000)
    }

    @Test("El mensaje por falta de precio nombra la moneda faltante")
    func missingResolvedPriceMessageIncludesCurrency() {
        let message = CompletionConfigurationIssue
            .missingResolvedPrice
            .message(resolvedCurrencyCode: "ARS")

        #expect(message.contains("ARS"))
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
        let schema = Schema(AppSchemaV4.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
