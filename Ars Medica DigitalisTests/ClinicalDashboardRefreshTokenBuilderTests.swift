//
//  ClinicalDashboardRefreshTokenBuilderTests.swift
//  Ars Medica DigitalisTests
//
//  Verifica estabilidad del token de refresco del dashboard clínico.
//

import Foundation
import Testing
@testable import Ars_Medica_Digitalis

struct ClinicalDashboardRefreshTokenBuilderTests {

    @Test
    func tokenIsOrderIndependent() {
        let now = Date()
        let patientA = ClinicalDashboardRefreshTokenBuilder.EntityStamp(id: UUID(), date: now)
        let patientB = ClinicalDashboardRefreshTokenBuilder.EntityStamp(id: UUID(), date: now.addingTimeInterval(30))
        let sessionA = ClinicalDashboardRefreshTokenBuilder.EntityStamp(id: UUID(), date: now.addingTimeInterval(60))
        let paymentA = ClinicalDashboardRefreshTokenBuilder.EntityStamp(id: UUID(), date: now.addingTimeInterval(90))
        let diagnosisA = ClinicalDashboardRefreshTokenBuilder.EntityStamp(id: UUID(), date: now.addingTimeInterval(120))

        let tokenAB = ClinicalDashboardRefreshTokenBuilder.token(
            patients: [patientA, patientB],
            sessions: [sessionA],
            payments: [paymentA],
            diagnoses: [diagnosisA]
        )

        let tokenBA = ClinicalDashboardRefreshTokenBuilder.token(
            patients: [patientB, patientA],
            sessions: [sessionA],
            payments: [paymentA],
            diagnoses: [diagnosisA]
        )

        #expect(tokenAB == tokenBA)
    }

    @Test
    func tokenChangesWhenAnyTimestampChanges() {
        let entityID = UUID()
        let original = ClinicalDashboardRefreshTokenBuilder.EntityStamp(
            id: entityID,
            date: Date(timeIntervalSinceReferenceDate: 1_000)
        )
        let updated = ClinicalDashboardRefreshTokenBuilder.EntityStamp(
            id: entityID,
            date: Date(timeIntervalSinceReferenceDate: 2_000)
        )

        let baseline = ClinicalDashboardRefreshTokenBuilder.token(
            patients: [original],
            sessions: [],
            payments: [],
            diagnoses: []
        )
        let changed = ClinicalDashboardRefreshTokenBuilder.token(
            patients: [updated],
            sessions: [],
            payments: [],
            diagnoses: []
        )

        #expect(baseline != changed)
    }

    @Test
    func tokenChangesWhenCollectionsChange() {
        let basePatient = ClinicalDashboardRefreshTokenBuilder.EntityStamp(
            id: UUID(),
            date: Date(timeIntervalSinceReferenceDate: 100)
        )
        let extraPayment = ClinicalDashboardRefreshTokenBuilder.EntityStamp(
            id: UUID(),
            date: Date(timeIntervalSinceReferenceDate: 300)
        )

        let withoutPayment = ClinicalDashboardRefreshTokenBuilder.token(
            patients: [basePatient],
            sessions: [],
            payments: [],
            diagnoses: []
        )
        let withPayment = ClinicalDashboardRefreshTokenBuilder.token(
            patients: [basePatient],
            sessions: [],
            payments: [extraPayment],
            diagnoses: []
        )

        #expect(withoutPayment != withPayment)
    }
}
