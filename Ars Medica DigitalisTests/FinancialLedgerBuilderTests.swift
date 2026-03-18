//
//  FinancialLedgerBuilderTests.swift
//  Ars Medica Digitalis
//
//  Tests unitarios para FinancialLedgerBuilder.
//  Verifica las reglas de elegibilidad de billableSessions (fuente de verdad)
//  a través de la API pública: entries(for:currencyCode:) y availableCurrencies(for:).
//

import Foundation
import Testing
@testable import Ars_Medica_Digitalis

@MainActor
struct FinancialLedgerBuilderTests {

    // MARK: - Reglas de elegibilidad (billableSessions via API pública)

    @Test("Sesión no completada queda excluida del libro mayor")
    func incompleteSessionExcluded() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")
        let session = Session(
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            resolvedPrice: 100,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "ARS"
        )
        attach([session], to: patient)

        #expect(FinancialLedgerBuilder.availableCurrencies(for: patient).isEmpty)
        #expect(FinancialLedgerBuilder.entries(for: patient, currencyCode: "ARS").isEmpty)
    }

    @Test("Sesión cancelada queda excluida del libro mayor")
    func cancelledSessionExcluded() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")
        let session = Session(
            status: SessionStatusMapping.cancelada.rawValue,
            patient: patient,
            resolvedPrice: 100,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "ARS"
        )
        attach([session], to: patient)

        #expect(FinancialLedgerBuilder.availableCurrencies(for: patient).isEmpty)
        #expect(FinancialLedgerBuilder.entries(for: patient, currencyCode: "ARS").isEmpty)
    }

    @Test("Sesión de cortesía queda excluida del libro mayor")
    func courtesySessionExcluded() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            resolvedPrice: 100,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "ARS",
            isCourtesy: true
        )
        attach([session], to: patient)

        #expect(FinancialLedgerBuilder.availableCurrencies(for: patient).isEmpty)
        #expect(FinancialLedgerBuilder.entries(for: patient, currencyCode: "ARS").isEmpty)
    }

    @Test("Sesión completada con moneda vacía queda excluida del libro mayor")
    func sessionWithEmptyCurrencyExcluded() {
        // Patient sin moneda + sesión sin snapshot de moneda → currency resuelve a ""
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "")
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            resolvedPrice: 100
            // finalCurrencySnapshot nil, patient.currencyCode vacío → currency = ""
        )
        attach([session], to: patient)

        #expect(FinancialLedgerBuilder.availableCurrencies(for: patient).isEmpty)
    }

    @Test("Sesión completada con precio cero queda excluida del libro mayor")
    func sessionWithZeroPriceExcluded() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            resolvedPrice: 0,
            finalPriceSnapshot: 0,
            finalCurrencySnapshot: "ARS"
        )
        attach([session], to: patient)

        #expect(FinancialLedgerBuilder.availableCurrencies(for: patient).isEmpty)
        #expect(FinancialLedgerBuilder.entries(for: patient, currencyCode: "ARS").isEmpty)
    }

    @Test("Sesión completada facturable genera un cargo en el libro mayor")
    func billableSessionGeneratesCharge() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            resolvedPrice: 5000,
            finalPriceSnapshot: 5000,
            finalCurrencySnapshot: "ARS"
        )
        attach([session], to: patient)

        let currencies = FinancialLedgerBuilder.availableCurrencies(for: patient)
        #expect(currencies == ["ARS"])

        let entries = FinancialLedgerBuilder.entries(for: patient, currencyCode: "ARS")
        #expect(entries.count == 1)
        #expect(entries[0].kind == .charge)
        #expect(entries[0].amount == 5000)
    }

    @Test("entries y availableCurrencies son consistentes entre sí")
    func entriesAndAvailableCurrenciesAreConsistent() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "USD")
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            resolvedPrice: 100,
            finalPriceSnapshot: 100,
            finalCurrencySnapshot: "USD"
        )
        attach([session], to: patient)

        let currencies = FinancialLedgerBuilder.availableCurrencies(for: patient)
        for currency in currencies {
            let entries = FinancialLedgerBuilder.entries(for: patient, currencyCode: currency)
            #expect(!entries.isEmpty, "availableCurrencies reportó \(currency) pero entries está vacío")
        }
    }

    @Test("currencyCode vacío retorna lista vacía sin crash")
    func emptyCurrencyCodeReturnsEmpty() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        #expect(FinancialLedgerBuilder.entries(for: patient, currencyCode: "").isEmpty)
    }

    // MARK: - Saldo acumulado

    @Test("El saldo acumulado refleja cargos menos pagos en orden cronológico")
    func runningBalanceIsCorrect() {
        let past = Date().addingTimeInterval(-60 * 60 * 24 * 10)
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let session = Session(
            sessionDate: past,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: past,
            patient: patient,
            resolvedPrice: 5000,
            finalPriceSnapshot: 5000,
            finalCurrencySnapshot: "ARS"
        )

        let payment = Payment(
            amount: 2000,
            currencyCode: "ARS",
            paidAt: past.addingTimeInterval(60 * 60),
            session: session
        )
        attach([payment], to: session)
        attach([session], to: patient)

        let entries = FinancialLedgerBuilder.entries(for: patient, currencyCode: "ARS")
        #expect(entries.count == 2)

        let charge = entries.first { $0.kind == .charge }
        let pay = entries.first { $0.kind == .payment }
        #expect(charge?.runningBalance == 5000)
        #expect(pay?.runningBalance == 3000)
    }

    @Test("Cargo y pago simultáneos: el cargo precede al pago (sortOrder estable)")
    func chargePrecedesPaymentOnSameDate() {
        let now = Date()
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let session = Session(
            sessionDate: now,
            status: SessionStatusMapping.completada.rawValue,
            completedAt: now,
            patient: patient,
            resolvedPrice: 1000,
            finalPriceSnapshot: 1000,
            finalCurrencySnapshot: "ARS"
        )

        let payment = Payment(amount: 1000, currencyCode: "ARS", paidAt: now, session: session)
        attach([payment], to: session)
        attach([session], to: patient)

        let entries = FinancialLedgerBuilder.entries(for: patient, currencyCode: "ARS")
        #expect(entries.count == 2)
        #expect(entries[0].kind == .charge)
        #expect(entries[1].kind == .payment)
        #expect(entries[1].runningBalance == 0)
    }

    // MARK: - Helper

    private func attach(_ sessions: [Session], to patient: Patient) {
        for session in sessions {
            session.patient = patient
        }
        patient.sessions = sessions
    }

    private func attach(_ payments: [Payment], to session: Session) {
        for payment in payments {
            payment.session = session
        }
        session.payments = payments
    }
}
