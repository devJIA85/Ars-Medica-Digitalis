import Foundation
import SwiftData
import Testing
@testable import Ars_Medica_Digitalis

@MainActor
struct FinanceModuleTests {

    @Test("SessionPricingService.canResolvePrice con draft no inserta sesiones")
    func sessionPricingServiceCanResolvePriceDoesNotInsertSession() throws {
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

        let countBefore = try context.fetchCount(FetchDescriptor<Session>())
        let service = SessionPricingService(modelContext: context)
        let draft = SessionFinancialDraft(
            scheduledAt: now,
            patient: patient,
            financialSessionType: sessionType,
            isCourtesy: false,
            isCompleted: false
        )

        #expect(service.canResolvePrice(for: draft) == true)
        #expect(try context.fetchCount(FetchDescriptor<Session>()) == countBefore)
    }

    @Test("El precio dinámico cambia cuando cambia la moneda del paciente")
    func testDynamicPriceChangesWhenCurrencyChanges() throws {
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

        let sessionType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)

        let usdCurrency = PatientCurrencyVersion(
            currencyCode: "USD",
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24 * 7),
            patient: patient
        )
        context.insert(usdCurrency)

        let usdPrice = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24 * 7),
            price: 100,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(usdPrice)

        let eurPrice = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24 * 7),
            price: 80,
            currencyCode: "EUR",
            sessionCatalogType: sessionType
        )
        context.insert(eurPrice)

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: sessionType
        )
        context.insert(session)
        try context.save()

        #expect(session.effectiveCurrency == "USD")
        #expect(session.effectivePrice == 100)

        patient.currencyCode = "EUR"
        let eurCurrency = PatientCurrencyVersion(
            currencyCode: "EUR",
            effectiveFrom: now.addingTimeInterval(-60 * 60),
            patient: patient
        )
        context.insert(eurCurrency)
        try context.save()

        #expect(session.effectiveCurrency == "EUR")
        #expect(session.effectivePrice == 80)
    }

    @Test("Un honorario vigente desde hoy aplica a cualquier hora del mismo día")
    func testSameDayPriceVersionAppliesByDateNotByHour() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let sessionDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 3, hour: 2, minute: 10)
        )!
        let honorariumCreatedLaterSameDay = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 3, hour: 11, minute: 17)
        )!

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
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)

        let version = SessionTypePriceVersion(
            effectiveFrom: honorariumCreatedLaterSameDay,
            price: 55000,
            currencyCode: "ARS",
            sessionCatalogType: sessionType
        )
        context.insert(version)

        let session = Session(
            sessionDate: sessionDate,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: sessionType
        )
        context.insert(session)
        try context.save()

        #expect(session.effectiveCurrency == "ARS")
        #expect(session.effectivePrice == 55000)
    }

    @Test("Una sesión anterior al primer honorario usa el primer precio disponible")
    func testFirstHonorariumAppliesRetroactivelyWhenNoOlderPriceExists() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let sessionDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 2, hour: 10, minute: 5)
        )!
        let firstHonorariumDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 3, hour: 11, minute: 17)
        )!
        let laterHonorariumDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 10, hour: 9, minute: 0)
        )!

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
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)

        let firstVersion = SessionTypePriceVersion(
            effectiveFrom: firstHonorariumDate,
            price: 55000,
            currencyCode: "ARS",
            sessionCatalogType: sessionType
        )
        let laterVersion = SessionTypePriceVersion(
            effectiveFrom: laterHonorariumDate,
            price: 70000,
            currencyCode: "ARS",
            sessionCatalogType: sessionType
        )
        context.insert(firstVersion)
        context.insert(laterVersion)

        let session = Session(
            sessionDate: sessionDate,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: sessionType
        )
        context.insert(session)
        try context.save()

        #expect(session.effectiveCurrency == "ARS")
        #expect(session.effectivePrice == 55000)
    }

    @Test("El snapshot congela el precio al completar la sesión")
    func testSnapshotFreezesPriceOnCompletion() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Luis",
            lastName: "Paciente",
            currencyCode: "USD",
            professional: professional
        )
        context.insert(patient)

        let currencyVersion = PatientCurrencyVersion(
            currencyCode: "USD",
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24 * 10),
            patient: patient
        )
        context.insert(currencyVersion)

        let sessionType = SessionCatalogType(
            name: "Evaluación",
            professional: professional
        )
        context.insert(sessionType)

        let initialPrice = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24 * 10),
            price: 120,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(initialPrice)

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: sessionType
        )
        context.insert(session)
        try context.save()

        #expect(session.effectivePrice == 120)

        session.status = SessionStatusMapping.completada.rawValue
        let pricingService = SessionPricingService(modelContext: context)
        pricingService.finalizeSessionPricing(session: session)
        try context.save()

        let updatedPrice = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 30),
            price: 150,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(updatedPrice)
        try context.save()

        #expect(session.finalPriceSnapshot == 120)
        #expect(session.finalCurrencySnapshot == "USD")
        #expect(session.effectivePrice == 120)
        #expect(session.effectiveCurrency == "USD")
    }

    @Test("La sesión de cortesía siempre vale cero")
    func testCourtesySessionAlwaysZero() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Sofía",
            lastName: "Paciente",
            currencyCode: "USD",
            professional: professional
        )
        context.insert(patient)

        let sessionType = SessionCatalogType(
            name: "Cortesía",
            professional: professional
        )
        context.insert(sessionType)

        let version = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            price: 200,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(version)

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: sessionType,
            isCourtesy: true
        )
        context.insert(session)

        let payment = Payment(amount: 50, session: session)
        context.insert(payment)
        try context.save()

        #expect(session.effectivePrice == 0)
        #expect(session.debt == 0)
        #expect(session.paymentState == .paidFull)
    }

    @Test("Completar con pago total deja deuda cero")
    func testCompleteSessionWithFullPayment() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Julia",
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

        let sessionType = SessionCatalogType(name: "Individual", professional: professional)
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            price: 100,
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
        try viewModel.completeSession(session, in: context, paymentIntent: .full)

        #expect(session.finalPriceSnapshot == 100)
        #expect(session.totalPaid == 100)
        #expect(session.debt == 0)
        #expect(session.paymentState == .paidFull)
        #expect(session.payments.count == 1)
        #expect(session.payments.first?.currencyCode == "USD")
    }

    @Test("Completar con pago parcial calcula la deuda restante")
    func testCompleteSessionWithPartialPayment() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Bruno",
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

        let sessionType = SessionCatalogType(name: "Pareja", professional: professional)
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            price: 150,
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
        try viewModel.completeSession(session, in: context, paymentIntent: .partial(40))

        #expect(session.totalPaid == 40)
        #expect(session.debt == 110)
        #expect(session.paymentState == .paidPartial)
        #expect(session.payments.count == 1)
        #expect(session.payments.first?.amount == 40)
    }

    @Test("Completar sin pago deja la deuda total")
    func testCompleteSessionWithoutPayment() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "María",
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

        let sessionType = SessionCatalogType(name: "Evaluación", professional: professional)
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            price: 95,
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
        try viewModel.completeSession(session, in: context, paymentIntent: .none)

        #expect(session.totalPaid == 0)
        #expect(session.debt == 95)
        #expect(session.paymentState == .unpaid)
        #expect(session.payments.isEmpty)
    }

    @Test("Completar una cortesía no crea pagos")
    func testCompleteCourtesySessionDoesNotCreatePayment() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Lara",
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

        let sessionType = SessionCatalogType(name: "Cortesía", professional: professional)
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: now.addingTimeInterval(-60 * 60 * 24),
            price: 200,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(priceVersion)

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: sessionType,
            isCourtesy: true
        )
        context.insert(session)
        try context.save()

        let viewModel = SessionViewModel()
        try viewModel.completeSession(session, in: context, paymentIntent: .none)

        #expect(session.finalPriceSnapshot == 0)
        #expect(session.totalPaid == 0)
        #expect(session.debt == 0)
        #expect(session.paymentState == .paidFull)
        #expect(session.payments.isEmpty)
    }

    @Test("SessionTypeManagementViewModel renombra el tipo validando duplicados")
    func testSessionTypeManagementRenamesType() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let effectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let sessionType = SessionCatalogType(name: "Sesión Psi", professional: professional)
        let existing = SessionCatalogType(name: "Familiar", professional: professional)
        context.insert(sessionType)
        context.insert(existing)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: effectiveFrom,
            price: 55_000,
            currencyCode: "ARS",
            sessionCatalogType: sessionType
        )
        context.insert(priceVersion)
        try context.save()

        let snapshot = SessionTypeBusinessSnapshot(
            sessionType: sessionType,
            currentPrice: 55_000,
            currentCurrencyCode: "ARS",
            effectiveFrom: effectiveFrom,
            lastPriceVersion: priceVersion,
            monthsSinceLastUpdate: 0,
            ipcAccumulated: 0,
            shouldSuggestUpdate: false,
            suggestedPrice: nil
        )

        let viewModel = SessionTypeManagementViewModel(
            snapshot: snapshot,
            professional: professional,
            context: context
        )
        viewModel.name = "Individual"

        try viewModel.save()

        #expect(sessionType.name == "Individual")

        viewModel.name = " familiar "

        #expect(throws: SessionTypeManagementError.duplicateName) {
            try viewModel.save()
        }
    }

    @Test("SessionTypeManagementViewModel da de baja un tipo y limpia el default")
    func testSessionTypeManagementArchivesTypeAndClearsDefault() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let effectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let sessionType = SessionCatalogType(name: "Sesión Psi", professional: professional)
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: effectiveFrom,
            price: 55_000,
            currencyCode: "ARS",
            sessionCatalogType: sessionType
        )
        context.insert(priceVersion)
        professional.defaultFinancialSessionTypeID = sessionType.id
        try context.save()

        let snapshot = SessionTypeBusinessSnapshot(
            sessionType: sessionType,
            currentPrice: 55_000,
            currentCurrencyCode: "ARS",
            effectiveFrom: effectiveFrom,
            lastPriceVersion: priceVersion,
            monthsSinceLastUpdate: 0,
            ipcAccumulated: 0,
            shouldSuggestUpdate: false,
            suggestedPrice: nil
        )

        let viewModel = SessionTypeManagementViewModel(
            snapshot: snapshot,
            professional: professional,
            context: context
        )

        try viewModel.archive()

        #expect(sessionType.isActive == false)
        #expect(professional.defaultFinancialSessionTypeID == nil)
    }

    @Test("SessionTypeManagementViewModel crea una nueva versión manual y actualiza apariencia")
    func testSessionTypeManagementCreatesManualVersionAndUpdatesAppearance() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let initialEffectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()
        let updatedEffectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let sessionType = SessionCatalogType(name: "Sesión Psi", professional: professional)
        context.insert(sessionType)

        let initialVersion = SessionTypePriceVersion(
            effectiveFrom: initialEffectiveFrom,
            price: 55_000,
            currencyCode: "ARS",
            sessionCatalogType: sessionType
        )
        context.insert(initialVersion)
        try context.save()

        let snapshot = SessionTypeBusinessSnapshot(
            sessionType: sessionType,
            currentPrice: 55_000,
            currentCurrencyCode: "ARS",
            effectiveFrom: initialEffectiveFrom,
            lastPriceVersion: initialVersion,
            monthsSinceLastUpdate: 0,
            ipcAccumulated: 0,
            shouldSuggestUpdate: false,
            suggestedPrice: nil
        )

        let viewModel = SessionTypeManagementViewModel(
            snapshot: snapshot,
            professional: professional,
            context: context
        )
        viewModel.price = 63_500
        viewModel.currencyCode = "USD"
        viewModel.effectiveFrom = updatedEffectiveFrom
        viewModel.colorToken = SessionTypeColorToken.green.rawValue
        viewModel.symbolName = "stethoscope"

        try viewModel.save()

        let sessionTypeID = sessionType.id
        let descriptor = FetchDescriptor<SessionTypePriceVersion>(
            predicate: #Predicate<SessionTypePriceVersion> { version in
                version.sessionCatalogType?.id == sessionTypeID
            },
            sortBy: [
                SortDescriptor(\SessionTypePriceVersion.effectiveFrom, order: .reverse),
                SortDescriptor(\SessionTypePriceVersion.updatedAt, order: .reverse),
            ]
        )
        let versions = try context.fetch(descriptor)
        let latestVersion = try #require(versions.first)

        #expect(sessionType.colorToken == SessionTypeColorToken.green.rawValue)
        #expect(sessionType.iconSystemName == "stethoscope")
        #expect(versions.count == 2)
        #expect(latestVersion.adjustmentSource == .manual)
        #expect(latestVersion.price == 63_500)
        #expect(latestVersion.currencyCode == "USD")
        #expect(latestVersion.effectiveFrom == calendar.startOfDay(for: updatedEffectiveFrom))
    }

    @Test("FinanceDashboardViewModel calcula cobrado, devengado y deuda por moneda")
    func testFinanceDashboardRefreshByCurrency() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()
        let currentMonthDay = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10)) ?? Date()
        let previousMonthDay = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patientA = Patient(firstName: "Ana", lastName: "Uno", professional: professional)
        let patientB = Patient(firstName: "Beto", lastName: "Dos", professional: professional)
        context.insert(patientA)
        context.insert(patientB)

        let usdSessionCurrent = Session(
            sessionDate: currentMonthDay,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: currentMonthDay,
            patient: patientA,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "USD"
        )
        context.insert(usdSessionCurrent)

        let usdPaymentCurrent = Payment(
            amount: 60,
            currencyCode: "USD",
            paidAt: currentMonthDay,
            session: usdSessionCurrent
        )
        context.insert(usdPaymentCurrent)

        let usdSessionPrevious = Session(
            sessionDate: previousMonthDay,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: previousMonthDay,
            patient: patientB,
            finalPriceSnapshot: 200,
            finalCurrencySnapshot: "USD"
        )
        context.insert(usdSessionPrevious)

        let eurSessionCurrent = Session(
            sessionDate: currentMonthDay,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: currentMonthDay,
            patient: patientA,
            finalPriceSnapshot: 80,
            finalCurrencySnapshot: "EUR"
        )
        context.insert(eurSessionCurrent)

        let eurPaymentCurrent = Payment(
            amount: 80,
            currencyCode: "EUR",
            paidAt: currentMonthDay,
            session: eurSessionCurrent
        )
        context.insert(eurPaymentCurrent)

        try context.save()

        let viewModel = FinanceDashboardViewModel(selectedMonth: month, calendar: calendar)
        viewModel.selectedCurrency = "USD"
        try viewModel.refresh(in: context)

        #expect(viewModel.availableCurrencies == ["EUR", "USD"])
        #expect(viewModel.selectedCurrency == "USD")
        #expect(viewModel.monthlyCollected == 60)
        #expect(viewModel.monthlyAccrued == 100)
        #expect(viewModel.totalDebt == 240)
        #expect(viewModel.debtByPatient.count == 2)
        #expect(viewModel.debtByPatient.first?.patientName == "Beto Dos")
        #expect(viewModel.debtByPatient.first?.debt == 200)
        #expect(viewModel.debtByPatient.last?.patientName == "Ana Uno")
        #expect(viewModel.debtByPatient.last?.debt == 40)
    }

    @Test("FinanceDashboardViewModel selecciona la primera moneda disponible si la actual no existe")
    func testFinanceDashboardRefreshResolvesMissingCurrency() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()
        let completedAt = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(firstName: "Elena", lastName: "Paciente", professional: professional)
        context.insert(patient)

        let session = Session(
            sessionDate: completedAt,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: completedAt,
            patient: patient,
            finalPriceSnapshot: 70,
            finalCurrencySnapshot: "EUR"
        )
        context.insert(session)

        let payment = Payment(
            amount: 70,
            currencyCode: "EUR",
            paidAt: completedAt,
            session: session
        )
        context.insert(payment)
        try context.save()

        let viewModel = FinanceDashboardViewModel(selectedMonth: month, calendar: calendar)
        viewModel.selectedCurrency = "USD"
        try viewModel.refresh(in: context)

        #expect(viewModel.availableCurrencies == ["EUR"])
        #expect(viewModel.selectedCurrency == "EUR")
        #expect(viewModel.monthlyCollected == 70)
        #expect(viewModel.monthlyAccrued == 70)
        #expect(viewModel.totalDebt == 0)
        #expect(viewModel.debtByPatient.isEmpty)
    }

    @Test("FinanceDashboardViewModel incluye deuda histórica aun si faltan snapshots finales")
    func testFinanceDashboardIncludesCompletedDebtWithoutSnapshots() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()
        let completedAt = calendar.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 10, minute: 5)) ?? Date()
        let effectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Mari",
            lastName: "Kita",
            currencyCode: "ARS",
            professional: professional
        )
        context.insert(patient)

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "ARS",
                effectiveFrom: effectiveFrom,
                patient: patient
            )
        )

        let sessionType = SessionCatalogType(
            name: "Sesión Psi",
            professional: professional
        )
        context.insert(sessionType)

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: effectiveFrom,
                price: 55,
                currencyCode: "ARS",
                sessionCatalogType: sessionType
            )
        )

        let completedSession = Session(
            sessionDate: completedAt,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: completedAt,
            patient: patient,
            financialSessionType: sessionType,
            finalPriceSnapshot: nil,
            finalCurrencySnapshot: nil
        )
        context.insert(completedSession)
        try context.save()

        let viewModel = FinanceDashboardViewModel(selectedMonth: month, calendar: calendar)
        viewModel.selectedCurrency = "ARS"
        try viewModel.refresh(in: context)

        #expect(viewModel.availableCurrencies == ["ARS"])
        #expect(viewModel.monthlyAccrued == 55)
        #expect(viewModel.totalDebt == 55)
        #expect(viewModel.debtByPatient.count == 1)
        #expect(viewModel.debtByPatient.first?.patientName == "Mari Kita")
        #expect(viewModel.debtByPatient.first?.debt == 55)
    }

    @Test("FinanceDashboardViewModel incluye deuda cuando la sesión está completada pero completedAt falta")
    func testFinanceDashboardIncludesCompletedDebtWithoutCompletedAt() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()
        let sessionDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 10, minute: 5)) ?? Date()
        let effectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Mari",
            lastName: "Kita",
            currencyCode: "ARS",
            professional: professional
        )
        context.insert(patient)

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "ARS",
                effectiveFrom: effectiveFrom,
                patient: patient
            )
        )

        let sessionType = SessionCatalogType(
            name: "Sesión Psi",
            professional: professional
        )
        context.insert(sessionType)

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: effectiveFrom,
                price: 55,
                currencyCode: "ARS",
                sessionCatalogType: sessionType
            )
        )

        let completedSession = Session(
            sessionDate: sessionDate,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: nil,
            patient: patient,
            financialSessionType: sessionType,
            finalPriceSnapshot: nil,
            finalCurrencySnapshot: nil
        )
        context.insert(completedSession)
        try context.save()

        let viewModel = FinanceDashboardViewModel(selectedMonth: month, calendar: calendar)
        viewModel.selectedCurrency = "ARS"
        try viewModel.refresh(in: context)

        #expect(viewModel.availableCurrencies == ["ARS"])
        #expect(viewModel.monthlyAccrued == 55)
        #expect(viewModel.totalDebt == 55)
        #expect(viewModel.debtByPatient.count == 1)
        #expect(viewModel.debtByPatient.first?.patientName == "Mari Kita")
        #expect(viewModel.debtByPatient.first?.debt == 55)
    }

    @Test("SessionTypeCatalogViewModel arma precios vigentes, historial e impacto futuro")
    func testSessionTypeCatalogRefreshBuildsStrategicSummary() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 10)) ?? Date()

        let professional = Professional(fullName: "Profesional Titular")
        let otherProfessional = Professional(fullName: "Profesional Ajeno")
        context.insert(professional)
        context.insert(otherProfessional)

        let individual = SessionCatalogType(
            name: "Individual",
            isActive: true,
            sortOrder: 1,
            professional: professional
        )
        let supervision = SessionCatalogType(
            name: "Supervisión",
            isActive: false,
            sortOrder: 0,
            professional: professional
        )
        let foreignType = SessionCatalogType(
            name: "Ajeno",
            professional: otherProfessional
        )
        context.insert(individual)
        context.insert(supervision)
        context.insert(foreignType)

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(),
                price: 100,
                currencyCode: "USD",
                sessionCatalogType: individual
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date(),
                price: 120,
                currencyCode: "USD",
                sessionCatalogType: individual
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)) ?? Date(),
                price: 140,
                currencyCode: "USD",
                sessionCatalogType: individual
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)) ?? Date(),
                price: 80,
                currencyCode: "EUR",
                sessionCatalogType: individual
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 1, day: 10)) ?? Date(),
                price: 60,
                currencyCode: "USD",
                sessionCatalogType: supervision
            )
        )
        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 1, day: 10)) ?? Date(),
                price: 999,
                currencyCode: "USD",
                sessionCatalogType: foreignType
            )
        )

        let patientUSD = Patient(
            firstName: "Ana",
            lastName: "USD",
            currencyCode: "USD",
            professional: professional
        )
        let patientVIP = Patient(
            firstName: "Vera",
            lastName: "VIP",
            currencyCode: "USD",
            professional: professional
        )
        let patientEUR = Patient(
            firstName: "Eva",
            lastName: "EUR",
            currencyCode: "EUR",
            professional: professional
        )
        context.insert(patientUSD)
        context.insert(patientVIP)
        context.insert(patientEUR)

        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(),
                patient: patientUSD
            )
        )
        context.insert(
            PatientCurrencyVersion(
                currencyCode: "USD",
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(),
                patient: patientVIP
            )
        )
        context.insert(
            PatientCurrencyVersion(
                currencyCode: "EUR",
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(),
                patient: patientEUR
            )
        )

        context.insert(
            PatientSessionDefaultPrice(
                price: 90,
                currencyCode: "USD",
                patient: patientVIP,
                sessionCatalogType: individual
            )
        )

        context.insert(
            Session(
                sessionDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 9)) ?? Date(),
                status: SessionStatusMapping.programada.rawValue,
                patient: patientUSD,
                financialSessionType: individual
            )
        )
        context.insert(
            Session(
                sessionDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 9)) ?? Date(),
                status: SessionStatusMapping.programada.rawValue,
                patient: patientVIP,
                financialSessionType: individual
            )
        )
        context.insert(
            Session(
                sessionDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 25, hour: 9)) ?? Date(),
                status: SessionStatusMapping.programada.rawValue,
                patient: patientEUR,
                financialSessionType: individual
            )
        )
        context.insert(
            Session(
                sessionDate: calendar.date(from: DateComponents(year: 2026, month: 4, day: 3, hour: 9)) ?? Date(),
                status: SessionStatusMapping.programada.rawValue,
                patient: patientUSD,
                financialSessionType: individual
            )
        )
        context.insert(
            Session(
                sessionDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 26, hour: 9)) ?? Date(),
                status: SessionStatusMapping.programada.rawValue,
                patient: patientUSD,
                financialSessionType: individual,
                priceWasManuallyOverridden: true
            )
        )
        context.insert(
            Session(
                sessionDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 27, hour: 9)) ?? Date(),
                status: SessionStatusMapping.cancelada.rawValue,
                patient: patientUSD,
                financialSessionType: individual
            )
        )
        context.insert(
            Session(
                sessionDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 9)) ?? Date(),
                status: SessionStatusMapping.programada.rawValue,
                patient: patientUSD,
                financialSessionType: individual,
                isCourtesy: true
            )
        )

        try context.save()

        let viewModel = SessionTypeCatalogViewModel(
            referenceDate: referenceDate,
            calendar: calendar
        )
        try viewModel.refresh(for: professional, in: context)

        #expect(viewModel.catalogSummaries.count == 2)
        #expect(viewModel.catalogSummaries.map(\.sessionType.name) == ["Individual", "Supervisión"])

        let summary = try #require(viewModel.catalogSummaries.first)
        #expect(summary.affectedFutureSessionsCount == 4)
        #expect(summary.currentPrices.count == 2)
        #expect(summary.currentPrices.first?.currencyCode == "EUR")
        #expect(summary.currentPrices.first?.price == 80)
        #expect(summary.currentPrices.last?.currencyCode == "USD")
        #expect(summary.currentPrices.last?.price == 120)
        #expect(summary.projectedMonthlyImpact == [
            HonorariumAmount(currencyCode: "EUR", amount: 80),
            HonorariumAmount(currencyCode: "USD", amount: 210),
        ])
        #expect(summary.priceHistory.count == 4)
        #expect(summary.priceHistory.first?.currencyCode == "USD")
        #expect(summary.priceHistory.first?.price == 140)
        #expect(summary.priceHistory.first?.isCurrent == false)
        #expect(summary.priceHistory[1].price == 120)
        #expect(summary.priceHistory[1].effectiveUntil == calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)))
        #expect(summary.priceHistory[1].isCurrent)

        #expect(viewModel.averageCurrentPrices == [
            HonorariumAmount(currencyCode: "EUR", amount: 80),
            HonorariumAmount(currencyCode: "USD", amount: 90),
        ])
    }

    @Test("SessionTypeCatalogViewModel no marca como vigente un precio solo futuro")
    func testSessionTypeCatalogRefreshDoesNotPromoteFuturePrice() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let evaluation = SessionCatalogType(
            name: "Evaluación",
            professional: professional
        )
        context.insert(evaluation)

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)) ?? Date(),
                price: 130,
                currencyCode: "USD",
                sessionCatalogType: evaluation
            )
        )
        try context.save()

        let viewModel = SessionTypeCatalogViewModel(
            referenceDate: referenceDate,
            calendar: calendar
        )
        try viewModel.refresh(for: professional, in: context)

        let summary = try #require(viewModel.catalogSummaries.first)
        #expect(summary.currentPrices.isEmpty)
        #expect(summary.priceHistory.count == 1)
        #expect(summary.priceHistory.first?.price == 130)
        #expect(summary.priceHistory.first?.isCurrent == false)
        #expect(viewModel.averageCurrentPrices.isEmpty)
    }

    @Test("El motor sugiere ajuste cuando se supera la frecuencia configurada")
    func testSuggestionTriggeredByMonths() {
        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 3,
            ipcThreshold: Decimal(string: "0.20"),
            isEnabled: true
        )
        let engine = AdjustmentSuggestionEngine()

        let suggestion = engine.evaluate(
            currentPrice: 100,
            monthsSinceUpdate: 4,
            ipcAccumulated: Decimal(string: "0.02") ?? 0,
            policy: policy
        )

        #expect(suggestion.shouldSuggest)
        #expect(suggestion.monthsSinceUpdate == 4)
    }

    @Test("El motor sugiere ajuste cuando el IPC supera el umbral")
    func testSuggestionTriggeredByIPCThreshold() {
        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 6,
            ipcThreshold: Decimal(string: "0.10"),
            isEnabled: true
        )
        let engine = AdjustmentSuggestionEngine()

        let suggestion = engine.evaluate(
            currentPrice: 100,
            monthsSinceUpdate: 2,
            ipcAccumulated: Decimal(string: "0.12") ?? 0,
            policy: policy
        )

        #expect(suggestion.shouldSuggest)
        #expect(suggestion.ipcAccumulated == Decimal(string: "0.12"))
    }

    @Test("El motor no sugiere nada cuando la política está deshabilitada")
    func testNoSuggestionWhenPolicyDisabled() {
        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 1,
            ipcThreshold: Decimal(string: "0.01"),
            isEnabled: false
        )
        let engine = AdjustmentSuggestionEngine()

        let suggestion = engine.evaluate(
            currentPrice: 100,
            monthsSinceUpdate: 12,
            ipcAccumulated: Decimal(string: "0.50") ?? 0,
            policy: policy
        )

        #expect(suggestion.shouldSuggest == false)
        #expect(suggestion.suggestedPrice == nil)
    }

    @Test("El motor calcula el precio sugerido aplicando IPC acumulado")
    func testSuggestedPriceCalculation() {
        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 1,
            isEnabled: true
        )
        let engine = AdjustmentSuggestionEngine()

        let suggestion = engine.evaluate(
            currentPrice: 100,
            monthsSinceUpdate: 1,
            ipcAccumulated: Decimal(string: "0.10") ?? 0,
            policy: policy
        )

        #expect(suggestion.shouldSuggest)
        #expect(suggestion.suggestedPrice == 110)
    }

    @Test("El precio sugerido se redondea explícitamente a dos decimales")
    func testSuggestedPriceRoundsToTwoDecimals() {
        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 1,
            isEnabled: true
        )
        let engine = AdjustmentSuggestionEngine()

        let suggestion = engine.evaluate(
            currentPrice: Decimal(string: "100") ?? 0,
            monthsSinceUpdate: 1,
            ipcAccumulated: Decimal(string: "0.10555") ?? 0,
            policy: policy
        )

        #expect(suggestion.shouldSuggest)
        #expect(suggestion.suggestedPrice == Decimal(string: "110.56"))
    }

    @Test("La referencia global pisa la fecha de la última versión del tipo")
    func testGlobalReferenceDateOverridesTypeDate() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)) ?? Date()
        let typeDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date()
        let globalReferenceDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 12,
            ipcThreshold: Decimal(string: "0.50"),
            isEnabled: true,
            globalReferenceDate: globalReferenceDate,
            professional: professional
        )
        context.insert(policy)
        professional.pricingAdjustmentPolicy = policy

        let sessionType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)

        let priceVersion = SessionTypePriceVersion(
            effectiveFrom: typeDate,
            price: 100,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(priceVersion)
        try context.save()

        let service = SessionTypeBusinessService(
            ipcIndicatorService: IPCIndicatorService(calendar: calendar),
            calendar: calendar
        )

        let snapshot = try await service.businessSnapshot(
            for: sessionType,
            context: context,
            at: referenceDate
        )

        #expect(snapshot.monthsSinceLastUpdate == 1)
        #expect(snapshot.ipcAccumulated == Decimal(string: "0.03"))
        #expect(snapshot.shouldSuggestUpdate == false)
        #expect(snapshot.suggestedPrice == nil)
    }

    @Test("SessionTypeBusinessViewModel devuelve snapshots calculados")
    func testBusinessViewModelReturnsSnapshots() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)) ?? Date()
        let effectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 12,
            isEnabled: true,
            professional: professional
        )
        context.insert(policy)
        professional.pricingAdjustmentPolicy = policy

        let sessionType = SessionCatalogType(
            name: "Individual",
            professional: professional
        )
        context.insert(sessionType)

        let version = SessionTypePriceVersion(
            effectiveFrom: effectiveFrom,
            price: 150,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(version)
        try context.save()

        let viewModel = SessionTypeBusinessViewModel(
            professional: professional,
            context: context,
            referenceDate: referenceDate
        )
        try await viewModel.refresh()

        #expect(viewModel.snapshots.count == 1)
        #expect(viewModel.snapshots.first?.currentPrice == 150)
        #expect(viewModel.snapshots.first?.currentCurrencyCode == "USD")
        #expect(viewModel.snapshots.first?.effectiveFrom == effectiveFrom)
        #expect(viewModel.snapshots.first?.shouldSuggestUpdate == false)
        #expect(viewModel.snapshots.first?.suggestedPrice == nil)
    }

    @Test("SessionTypeBusinessViewModel respeta la política y sugiere ajuste")
    func testBusinessViewModelRespectsPolicy() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)) ?? Date()
        let effectiveFrom = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 3,
            ipcThreshold: Decimal(string: "0.90"),
            isEnabled: true,
            professional: professional
        )
        context.insert(policy)
        professional.pricingAdjustmentPolicy = policy

        let sessionType = SessionCatalogType(
            name: "Evaluación",
            professional: professional
        )
        context.insert(sessionType)

        context.insert(
            SessionTypePriceVersion(
                effectiveFrom: effectiveFrom,
                price: 100,
                currencyCode: "USD",
                sessionCatalogType: sessionType
            )
        )
        try context.save()

        let service = SessionTypeBusinessService(
            ipcIndicatorService: IPCIndicatorService(calendar: calendar),
            calendar: calendar
        )
        let viewModel = SessionTypeBusinessViewModel(
            professional: professional,
            context: context,
            service: service,
            referenceDate: referenceDate
        )

        try await viewModel.refresh()
        let snapshot = try #require(viewModel.snapshots.first)

        #expect(snapshot.monthsSinceLastUpdate >= 3)
        #expect(snapshot.shouldSuggestUpdate)
        #expect(snapshot.suggestedPrice != nil)
    }

    @Test("SessionTypeBusinessViewModel maneja catálogo vacío")
    func testBusinessViewModelHandlesEmptyCatalog() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)
        try context.save()

        let viewModel = SessionTypeBusinessViewModel(
            professional: professional,
            context: context
        )
        try await viewModel.refresh()

        #expect(viewModel.snapshots.isEmpty)
    }

    @Test("Aplicar actualización sugerida crea una nueva versión IPC y apaga la sugerencia")
    func testApplyingIPCSuggestedUpdateCreatesNewVersion() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let initialEffectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date()
        let updateDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 10)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let policy = PricingAdjustmentPolicy(
            frequencyInMonths: 3,
            isEnabled: true,
            professional: professional
        )
        context.insert(policy)
        professional.pricingAdjustmentPolicy = policy

        let sessionType = SessionCatalogType(name: "Individual", professional: professional)
        context.insert(sessionType)

        let initialVersion = SessionTypePriceVersion(
            effectiveFrom: initialEffectiveFrom,
            price: 100,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(initialVersion)
        try context.save()

        let snapshot = SessionTypeBusinessSnapshot(
            sessionType: sessionType,
            currentPrice: 100,
            currentCurrencyCode: "USD",
            effectiveFrom: initialEffectiveFrom,
            lastPriceVersion: initialVersion,
            monthsSinceLastUpdate: 3,
            ipcAccumulated: Decimal(string: "0.09") ?? 0,
            shouldSuggestUpdate: true,
            suggestedPrice: 109
        )

        let updateViewModel = SessionTypePriceUpdateViewModel(
            snapshot: snapshot,
            professional: professional,
            context: context,
            nowProvider: { updateDate }
        )

        try updateViewModel.applyUpdate()

        let sessionTypeID = sessionType.id
        let versionsDescriptor = FetchDescriptor<SessionTypePriceVersion>(
            predicate: #Predicate<SessionTypePriceVersion> { version in
                version.sessionCatalogType?.id == sessionTypeID
            },
            sortBy: [
                SortDescriptor(\SessionTypePriceVersion.effectiveFrom, order: .reverse),
                SortDescriptor(\SessionTypePriceVersion.updatedAt, order: .reverse),
            ]
        )
        let versions = try context.fetch(versionsDescriptor)
        let latestVersion = try #require(versions.first)

        #expect(versions.count == 2)
        #expect(latestVersion.adjustmentSource == .ipcSuggested)
        #expect(latestVersion.price == 109)
        #expect(latestVersion.currencyCode == "USD")
        #expect(latestVersion.effectiveFrom == calendar.startOfDay(for: updateDate))

        let service = SessionTypeBusinessService(
            ipcIndicatorService: IPCIndicatorService(calendar: calendar),
            calendar: calendar
        )
        let refreshedSnapshot = try await service.businessSnapshot(
            for: sessionType,
            context: context,
            at: updateDate
        )

        #expect(refreshedSnapshot.currentPrice == 109)
        #expect(refreshedSnapshot.monthsSinceLastUpdate == 0)
        #expect(refreshedSnapshot.ipcAccumulated == 0)
        #expect(refreshedSnapshot.shouldSuggestUpdate == false)
        #expect(refreshedSnapshot.suggestedPrice == nil)
    }

    @Test("Aplicar actualización sugerida repricing sesiones futuras sin tocar snapshots completados")
    func testApplyingSuggestedUpdateRepricesFutureSessionsWithoutChangingCompletedSnapshots() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let initialEffectiveFrom = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date()
        let updateDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 9)) ?? Date()
        let completedDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 15)) ?? Date()
        let futureSessionDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10)) ?? Date()

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
            effectiveFrom: initialEffectiveFrom,
            patient: patient
        )
        context.insert(currencyVersion)

        let sessionType = SessionCatalogType(name: "Individual", professional: professional)
        context.insert(sessionType)

        let initialVersion = SessionTypePriceVersion(
            effectiveFrom: initialEffectiveFrom,
            price: 100,
            currencyCode: "USD",
            sessionCatalogType: sessionType
        )
        context.insert(initialVersion)

        let futureSession = Session(
            sessionDate: futureSessionDate,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: sessionType
        )
        context.insert(futureSession)

        let completedSession = Session(
            sessionDate: completedDate,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: completedDate,
            patient: patient,
            financialSessionType: sessionType,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "USD"
        )
        context.insert(completedSession)
        try context.save()

        let snapshot = SessionTypeBusinessSnapshot(
            sessionType: sessionType,
            currentPrice: 100,
            currentCurrencyCode: "USD",
            effectiveFrom: initialEffectiveFrom,
            lastPriceVersion: initialVersion,
            monthsSinceLastUpdate: 2,
            ipcAccumulated: Decimal(string: "0.20") ?? 0,
            shouldSuggestUpdate: true,
            suggestedPrice: 120
        )

        let updateViewModel = SessionTypePriceUpdateViewModel(
            snapshot: snapshot,
            professional: professional,
            context: context,
            nowProvider: { updateDate }
        )

        try updateViewModel.applyUpdate()

        #expect(futureSession.effectivePrice == 120)
        #expect(futureSession.effectiveCurrency == "USD")
        #expect(completedSession.effectivePrice == 100)
        #expect(completedSession.finalPriceSnapshot == 100)
        #expect(completedSession.finalCurrencySnapshot == "USD")
    }

    @Test("Cancelar deuda parcial distribuye el pago desde la sesión más antigua")
    func testPatientDebtSettlementAppliesPartialPaymentOldestFirst() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let olderDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)) ?? Date()
        let newerDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Ana",
            lastName: "Paciente",
            professional: professional
        )
        context.insert(patient)

        let olderSession = Session(
            sessionDate: olderDate,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: olderDate,
            patient: patient,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "ARS"
        )
        let newerSession = Session(
            sessionDate: newerDate,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: newerDate,
            patient: patient,
            finalPriceSnapshot: 200,
            finalCurrencySnapshot: "ARS"
        )
        context.insert(olderSession)
        context.insert(newerSession)
        try context.save()

        let viewModel = PatientDebtSettlementViewModel(
            patient: patient,
            context: context,
            preferredCurrencyCode: "ARS"
        )
        try viewModel.refresh()
        viewModel.selectedOption = .partial
        viewModel.partialAmount = 150

        try viewModel.registerPayment()

        #expect(olderSession.totalPaid == 100)
        #expect(olderSession.debt == 0)
        #expect(newerSession.totalPaid == 50)
        #expect(newerSession.debt == 150)
        #expect(viewModel.totalDebt == 150)
    }

    @Test("Cancelar deuda total limpia la moneda seleccionada sin tocar otras deudas")
    func testPatientDebtSettlementAppliesFullPaymentOnlyToSelectedCurrency() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let now = Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "Ana",
            lastName: "Paciente",
            professional: professional
        )
        context.insert(patient)

        let arsSession = Session(
            sessionDate: now.addingTimeInterval(-60 * 60 * 24 * 2),
            status: SessionStatusMapping.completada.rawValue,
            completedAt: now.addingTimeInterval(-60 * 60 * 24 * 2),
            patient: patient,
            finalPriceSnapshot: 120,
            finalCurrencySnapshot: "ARS"
        )
        let usdSession = Session(
            sessionDate: now.addingTimeInterval(-60 * 60 * 24),
            status: SessionStatusMapping.completada.rawValue,
            completedAt: now.addingTimeInterval(-60 * 60 * 24),
            patient: patient,
            finalPriceSnapshot: 80,
            finalCurrencySnapshot: "USD"
        )
        context.insert(arsSession)
        context.insert(usdSession)
        try context.save()

        let viewModel = PatientDebtSettlementViewModel(
            patient: patient,
            context: context,
            preferredCurrencyCode: "ARS"
        )
        try viewModel.refresh()

        #expect(viewModel.selectedCurrency == "ARS")
        #expect(viewModel.totalDebt == 120)

        try viewModel.registerPayment()

        #expect(arsSession.debt == 0)
        #expect(usdSession.debt == 80)
        #expect(patient.debtByCurrency.count == 1)
        #expect(patient.debtByCurrency.first?.currencyCode == "USD")
    }

    @Test("Patient refleja en perfil que la deuda quedó cancelada tras registrar pago total")
    func testPatientDebtIndicatorsRefreshAfterFullSettlement() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let sessionDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 10)) ?? Date()

        let professional = Professional(fullName: "Profesional")
        context.insert(professional)

        let patient = Patient(
            firstName: "John",
            lastName: "Rambo",
            professional: professional
        )
        context.insert(patient)

        let session = Session(
            sessionDate: sessionDate,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: sessionDate,
            patient: patient,
            finalPriceSnapshot: 140,
            finalCurrencySnapshot: "ARS"
        )
        context.insert(session)
        try context.save()

        #expect(patient.hasOutstandingDebt == true)
        #expect(patient.debtByCurrency.first?.debt == 140)

        let viewModel = PatientDebtSettlementViewModel(
            patient: patient,
            context: context,
            preferredCurrencyCode: "ARS"
        )
        try viewModel.refresh()
        try viewModel.registerPayment()

        #expect(viewModel.totalDebt == 0)
        #expect(patient.hasOutstandingDebt == false)
        #expect(patient.debtByCurrency.isEmpty)
    }

    @Test("El highlight de honorarios no aparece cuando no hay sugerencia")
    func testHonorariosHighlightHiddenWhenSuggestionIsFalse() {
        let snapshot = makeHonorariosSnapshot(shouldSuggestUpdate: false)

        let shouldShow = HonorariosHighlightRules.shouldShowSuggestionHighlight(
            policy: nil,
            snapshot: snapshot,
            now: Date()
        )

        #expect(shouldShow == false)
    }

    @Test("El highlight de honorarios aparece si nunca fue descartado")
    func testHonorariosHighlightVisibleWhenNeverDismissed() {
        let snapshot = makeHonorariosSnapshot(shouldSuggestUpdate: true)
        let policy = PricingAdjustmentPolicy(lastSuggestionDismissedAt: nil)

        let shouldShow = HonorariosHighlightRules.shouldShowSuggestionHighlight(
            policy: policy,
            snapshot: snapshot,
            now: Date()
        )

        #expect(shouldShow)
    }

    @Test("El highlight de honorarios se oculta dentro de la ventana de cooldown")
    func testHonorariosHighlightHiddenWithinCooldown() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2)) ?? Date()
        let dismissedAt = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let snapshot = makeHonorariosSnapshot(shouldSuggestUpdate: true)
        let policy = PricingAdjustmentPolicy(lastSuggestionDismissedAt: dismissedAt)

        let shouldShow = HonorariosHighlightRules.shouldShowSuggestionHighlight(
            policy: policy,
            snapshot: snapshot,
            now: now,
            calendar: calendar
        )

        #expect(shouldShow == false)
    }

    @Test("El highlight de honorarios reaparece luego de siete días")
    func testHonorariosHighlightVisibleAfterCooldown() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2)) ?? Date()
        let dismissedAt = calendar.date(byAdding: .day, value: -8, to: now) ?? now
        let snapshot = makeHonorariosSnapshot(shouldSuggestUpdate: true)
        let policy = PricingAdjustmentPolicy(lastSuggestionDismissedAt: dismissedAt)

        let shouldShow = HonorariosHighlightRules.shouldShowSuggestionHighlight(
            policy: policy,
            snapshot: snapshot,
            now: now,
            calendar: calendar
        )

        #expect(shouldShow)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaV4.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func makeHonorariosSnapshot(
        shouldSuggestUpdate: Bool
    ) -> SessionTypeBusinessSnapshot {
        SessionTypeBusinessSnapshot(
            sessionType: SessionCatalogType(name: "Individual"),
            currentPrice: 100,
            currentCurrencyCode: "USD",
            effectiveFrom: Date(),
            lastPriceVersion: nil,
            monthsSinceLastUpdate: 4,
            ipcAccumulated: Decimal(string: "0.12") ?? 0,
            shouldSuggestUpdate: shouldSuggestUpdate,
            suggestedPrice: shouldSuggestUpdate ? 112 : nil
        )
    }
}
