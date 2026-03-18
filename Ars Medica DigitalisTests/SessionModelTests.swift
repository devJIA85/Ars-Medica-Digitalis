//
//  SessionModelTests.swift
//  Ars Medica Digitalis
//
//  Tests unitarios para Session.effectivePrice y Session.effectiveCurrency.
//  Verifica la estrategia snapshot vs. fallback y la regla de cortesía.
//  No necesita ModelContext: las propiedades bajo test solo leen campos
//  almacenados que se inicializan directamente en el constructor.
//

import Foundation
import Testing
@testable import Ars_Medica_Digitalis

@MainActor
struct SessionModelTests {

    // MARK: - effectivePrice

    @Test("Sesión de cortesía siempre tiene precio efectivo cero")
    func courtesySessionPriceIsZero() {
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            resolvedPrice: 5000,
            finalPriceSnapshot: 5000,
            isCourtesy: true
        )

        #expect(session.effectivePrice == 0)
    }

    @Test("Sesión completada con snapshot usa el snapshot como precio canónico")
    func completedSessionUsesSnapshot() {
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            resolvedPrice: 3000,       // valor dinámico — debe ignorarse
            finalPriceSnapshot: 5000   // snapshot fijado al cierre
        )

        #expect(session.effectivePrice == 5000)
    }

    @Test("Sesión completada sin snapshot cae en resolvedPrice")
    func completedSessionWithoutSnapshotFallsBackToResolvedPrice() {
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            resolvedPrice: 4000,
            finalPriceSnapshot: nil
        )

        #expect(session.effectivePrice == 4000)
    }

    @Test("Sesión abierta (programada) usa resolvedPrice")
    func openSessionUsesResolvedPrice() {
        let session = Session(
            status: SessionStatusMapping.programada.rawValue,
            resolvedPrice: 2500
        )

        #expect(session.effectivePrice == 2500)
    }

    @Test("Sesión abierta sin precio configurado retorna cero")
    func openSessionWithNoPriceReturnsZero() {
        let session = Session(
            status: SessionStatusMapping.programada.rawValue,
            resolvedPrice: 0
        )

        #expect(session.effectivePrice == 0)
    }

    // MARK: - effectiveCurrency

    @Test("Sesión completada con snapshot de moneda usa el snapshot")
    func completedSessionUsesCurrencySnapshot() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "USD")
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            finalCurrencySnapshot: "ARS"  // moneda al cierre — USD del paciente debe ignorarse
        )

        #expect(session.effectiveCurrency == "ARS")
    }

    @Test("Sesión completada sin snapshot de moneda cae en moneda del paciente")
    func completedSessionWithoutSnapshotFallsBackToPatientCurrency() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "EUR")
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            finalCurrencySnapshot: nil
        )

        #expect(session.effectiveCurrency == "EUR")
    }

    @Test("Sesión completada con snapshot vacío cae en moneda del paciente")
    func completedSessionWithEmptySnapshotFallsBackToPatientCurrency() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "USD")
        let session = Session(
            status: SessionStatusMapping.completada.rawValue,
            patient: patient,
            finalCurrencySnapshot: ""  // vacío no es válido como snapshot
        )

        #expect(session.effectiveCurrency == "USD")
    }

    @Test("Sesión abierta usa la moneda actual del paciente")
    func openSessionUsesPatientCurrency() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")
        let session = Session(
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )

        #expect(session.effectiveCurrency == "ARS")
    }

    @Test("Sesión sin paciente retorna moneda vacía")
    func sessionWithoutPatientReturnsEmptyCurrency() {
        let session = Session(
            status: SessionStatusMapping.programada.rawValue,
            patient: nil
        )

        #expect(session.effectiveCurrency == "")
    }

    // MARK: - isCompleted

    @Test("isCompleted es true solo para sesiones con status completada")
    func isCompletedTrueOnlyForCompletedStatus() {
        #expect(Session(status: SessionStatusMapping.completada.rawValue).isCompleted == true)
        #expect(Session(status: SessionStatusMapping.programada.rawValue).isCompleted == false)
        #expect(Session(status: SessionStatusMapping.cancelada.rawValue).isCompleted == false)
    }
}
