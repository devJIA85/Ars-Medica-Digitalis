//
//  DashboardViewModelTests.swift
//  Ars Medica Digitalis
//
//  Tests unitarios para DashboardViewModel.loadStatistics(from:).
//  Verifica KPIs, distribuciones y casos extremos sin ModelContext:
//  loadStatistics(from:) opera sobre el grafo de objetos en memoria.
//

import Foundation
import Testing
@testable import Ars_Medica_Digitalis

@MainActor
struct DashboardViewModelTests {

    // MARK: - Caso base vacío

    @Test("Sin pacientes, todos los KPIs son cero y las distribuciones están vacías")
    func emptyPatientsProducesZeroKPIs() {
        let vm = DashboardViewModel()
        vm.loadStatistics(from: [])

        #expect(vm.totalPatients == 0)
        #expect(vm.sessionsThisMonth == 0)
        #expect(vm.averageDurationMinutes == 0)
        #expect(vm.completionRate == 0)
        #expect(vm.sessionsByModality.isEmpty)
        #expect(vm.sessionsByStatus.isEmpty)
    }

    // MARK: - totalPatients

    @Test("totalPatients cuenta solo pacientes activos")
    func totalPatientsCountsOnlyActive() {
        let active = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let inactive = Patient(firstName: "Luis", lastName: "Pérez", currencyCode: "ARS")
        inactive.deletedAt = Date().addingTimeInterval(-86400)

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [active, inactive])

        #expect(vm.totalPatients == 1)
    }

    // MARK: - averageDurationMinutes

    @Test("averageDurationMinutes es la media de sesiones completadas")
    func averageDurationOnlyFromCompleted() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let s1 = Session(
            durationMinutes: 60,
            status: SessionStatusMapping.completada.rawValue,
            patient: patient
        )
        let s2 = Session(
            durationMinutes: 40,
            status: SessionStatusMapping.completada.rawValue,
            patient: patient
        )
        // Sesión programada: no debe entrar en el promedio
        let s3 = Session(
            durationMinutes: 90,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        patient.sessions = [s1, s2, s3]

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [patient])

        #expect(vm.averageDurationMinutes == 50.0)  // (60 + 40) / 2
    }

    @Test("averageDurationMinutes es cero cuando no hay sesiones completadas")
    func averageDurationZeroWithNoCompletedSessions() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let s = Session(
            durationMinutes: 60,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        patient.sessions = [s]

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [patient])

        #expect(vm.averageDurationMinutes == 0)
    }

    // MARK: - completionRate

    @Test("completionRate es 100 cuando todas las sesiones cerradas están completadas")
    func completionRateAllCompleted() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let s1 = Session(status: SessionStatusMapping.completada.rawValue, patient: patient)
        let s2 = Session(status: SessionStatusMapping.completada.rawValue, patient: patient)
        patient.sessions = [s1, s2]

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [patient])

        #expect(vm.completionRate == 100.0)
    }

    @Test("completionRate es 0 cuando solo hay sesiones programadas")
    func completionRateZeroWithOnlyScheduled() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let s = Session(status: SessionStatusMapping.programada.rawValue, patient: patient)
        patient.sessions = [s]

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [patient])

        // Scheduled sessions don't count toward the rate denominator
        #expect(vm.completionRate == 0)
    }

    @Test("completionRate ignora sesiones programadas en el denominador")
    func completionRateIgnoresScheduled() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        // 1 completada, 1 cancelada, 1 programada
        let s1 = Session(status: SessionStatusMapping.completada.rawValue, patient: patient)
        let s2 = Session(status: SessionStatusMapping.cancelada.rawValue, patient: patient)
        let s3 = Session(status: SessionStatusMapping.programada.rawValue, patient: patient)
        patient.sessions = [s1, s2, s3]

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [patient])

        // completada / (completada + cancelada) = 1/2 = 50%
        #expect(vm.completionRate == 50.0)
    }

    // MARK: - sessionsByModality y sessionsByStatus

    @Test("sessionsByModality contiene un segmento por modalidad presente")
    func sessionsByModalityContainsDistinctModalities() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let s1 = Session(
            sessionType: SessionTypeMapping.presencial.rawValue,
            status: SessionStatusMapping.completada.rawValue,
            patient: patient
        )
        let s2 = Session(
            sessionType: SessionTypeMapping.videollamada.rawValue,
            status: SessionStatusMapping.completada.rawValue,
            patient: patient
        )
        patient.sessions = [s1, s2]

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [patient])

        #expect(vm.sessionsByModality.count == 2)
        #expect(vm.sessionsByModality.allSatisfy { $0.count > 0 })
    }

    @Test("sessionsByStatus contiene un segmento por estado presente")
    func sessionsByStatusContainsDistinctStatuses() {
        let patient = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let s1 = Session(status: SessionStatusMapping.completada.rawValue, patient: patient)
        let s2 = Session(status: SessionStatusMapping.cancelada.rawValue, patient: patient)
        patient.sessions = [s1, s2]

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [patient])

        #expect(vm.sessionsByStatus.count == 2)
    }

    // MARK: - Pacientes inactivos excluidos del cómputo de sesiones

    @Test("Las sesiones de pacientes inactivos no aparecen en las distribuciones")
    func inactivePatientsSessionsExcluded() {
        let active = Patient(firstName: "Ana", lastName: "García", currencyCode: "ARS")

        let inactive = Patient(firstName: "Luis", lastName: "Pérez", currencyCode: "ARS")
        inactive.deletedAt = Date().addingTimeInterval(-86400)

        let activeSession = Session(status: SessionStatusMapping.completada.rawValue, patient: active)
        let inactiveSession = Session(status: SessionStatusMapping.completada.rawValue, patient: inactive)
        active.sessions = [activeSession]
        inactive.sessions = [inactiveSession]

        let vm = DashboardViewModel()
        vm.loadStatistics(from: [active, inactive])

        // Only active patient's session should be counted
        let totalSessionCount = vm.sessionsByStatus.reduce(0) { $0 + $1.count }
        #expect(totalSessionCount == 1)
    }
}
