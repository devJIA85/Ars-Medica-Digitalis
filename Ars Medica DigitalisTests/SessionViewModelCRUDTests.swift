//
//  SessionViewModelCRUDTests.swift
//  Ars Medica Digitalis
//
//  Tests de creación y edición de sesiones clínicas via SessionViewModel.
//  Cubre el camino crítico: alta, edición, sincronización de diagnósticos
//  vigentes y propagación de updatedAt al paciente.
//

import Foundation
import SwiftData
import Testing
@testable import Ars_Medica_Digitalis

@MainActor
struct SessionViewModelCRUDTests {

    // MARK: - createSession

    @Test("createSession persiste la sesión con los campos del ViewModel")
    func createSessionPersistsFields() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Dra. García")
        context.insert(professional)
        let patient = Patient(firstName: "Ana", lastName: "Pérez", professional: professional)
        context.insert(patient)
        try context.save()

        let vm = SessionViewModel()
        vm.chiefComplaint = "Ansiedad"
        vm.notes = "Primera consulta"
        vm.status = SessionStatusMapping.programada.rawValue
        vm.durationMinutes = 50

        let session = try vm.createSession(for: patient, in: context)

        #expect(session.chiefComplaint == "Ansiedad")
        #expect(session.notes == "Primera consulta")
        #expect(session.sessionStatusValue == .programada)
        #expect(session.durationMinutes == 50)
        #expect(session.patient?.id == patient.id)
    }

    @Test("createSession como cortesía no requiere tipo financiero")
    func createCourtesySessionPassesValidation() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Dr. López")
        context.insert(professional)
        let patient = Patient(firstName: "Carlos", lastName: "Ruiz", professional: professional)
        context.insert(patient)
        try context.save()

        let vm = SessionViewModel()
        vm.status = SessionStatusMapping.completada.rawValue
        vm.isCourtesy = true

        let session = try vm.createSession(for: patient, in: context)

        #expect(session.isCourtesy == true)
        #expect(session.debt == 0)
    }

    @Test("createSession programada incrementa el conteo de sesiones del paciente")
    func createSessionIncreasesPatientSessionCount() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Lic. Rodríguez")
        context.insert(professional)
        let patient = Patient(firstName: "María", lastName: "González", professional: professional)
        context.insert(patient)
        try context.save()

        let countBefore = patient.sessions.count

        let vm = SessionViewModel()
        vm.status = SessionStatusMapping.programada.rawValue
        _ = try vm.createSession(for: patient, in: context)

        #expect(patient.sessions.count == countBefore + 1)
    }

    @Test("createSession con diagnósticos actualiza updatedAt del paciente")
    func createSessionWithDiagnosisBumpsPatientUpdatedAt() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Lic. Rodríguez")
        context.insert(professional)
        let patient = Patient(firstName: "María", lastName: "González", professional: professional)
        context.insert(patient)
        let before = Date()
        patient.updatedAt = before.addingTimeInterval(-1)
        try context.save()

        let vm = SessionViewModel()
        vm.status = SessionStatusMapping.programada.rawValue
        // addDiagnosis activa didModifyDiagnoses → syncActiveDiagnoses → patient.updatedAt
        vm.addDiagnosis(ICD11SearchResult(
            id: "http://id.who.int/icd/entity/999",
            theCode: "F32",
            title: "Episodio depresivo",
            chapter: "06",
            score: nil
        ))
        _ = try vm.createSession(for: patient, in: context)

        #expect(patient.updatedAt >= before)
    }

    @Test("createSession con diagnósticos agrega Diagnosis a la sesión")
    func createSessionWithDiagnosisInsertsDiagnosis() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Dr. Test")
        context.insert(professional)
        let patient = Patient(firstName: "Pedro", lastName: "Sánchez", professional: professional)
        context.insert(patient)
        try context.save()

        let searchResult = ICD11SearchResult(
            id: "http://id.who.int/icd/entity/12345",
            theCode: "F41.1",
            title: "Trastorno de ansiedad generalizada",
            chapter: "06",
            score: nil
        )

        let vm = SessionViewModel()
        vm.status = SessionStatusMapping.programada.rawValue
        vm.addDiagnosis(searchResult)

        let session = try vm.createSession(for: patient, in: context)

        #expect(session.diagnoses?.count == 1)
        #expect(session.diagnoses?.first?.icdCode == "F41.1")
    }

    // MARK: - update

    @Test("update modifica los campos de la sesión")
    func updateModifiesSessionFields() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Dra. García")
        context.insert(professional)
        let patient = Patient(firstName: "Ana", lastName: "Pérez", professional: professional)
        context.insert(patient)
        let session = Session(
            sessionDate: Date(),
            notes: "Nota original",
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(session)
        try context.save()

        let vm = SessionViewModel()
        vm.load(from: session)
        vm.notes = "Nota actualizada"
        vm.chiefComplaint = "Insomnio"

        _ = try vm.update(session, in: context)

        #expect(session.notes == "Nota actualizada")
        #expect(session.chiefComplaint == "Insomnio")
    }

    @Test("update bumps updatedAt de la sesión")
    func updateBumpsSessionUpdatedAt() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Dra. García")
        context.insert(professional)
        let patient = Patient(firstName: "Ana", lastName: "Pérez", professional: professional)
        context.insert(patient)
        let before = Date()
        let session = Session(
            sessionDate: Date(),
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        session.updatedAt = before.addingTimeInterval(-1)
        context.insert(session)
        try context.save()

        let vm = SessionViewModel()
        vm.load(from: session)
        _ = try vm.update(session, in: context)

        #expect(session.updatedAt >= before)
    }

    @Test("update elimina diagnósticos de sesión que ya no están seleccionados")
    func updateRemovesDeselectedDiagnoses() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let professional = Professional(fullName: "Dr. Test")
        context.insert(professional)
        let patient = Patient(firstName: "Pedro", lastName: "Sánchez", professional: professional)
        context.insert(patient)
        let session = Session(
            sessionDate: Date(),
            status: SessionStatusMapping.programada.rawValue,
            patient: patient
        )
        context.insert(session)
        let existingResult = ICD11SearchResult(
            id: "http://id.who.int/icd/entity/111",
            theCode: "F41.1",
            title: "Ansiedad",
            chapter: "06",
            score: nil
        )
        let existingDiagnosis = Diagnosis(from: existingResult, session: session)
        context.insert(existingDiagnosis)
        try context.save()

        #expect(session.diagnoses?.count == 1)

        let vm = SessionViewModel()
        vm.load(from: session)
        // Remover todos los diagnósticos via API pública
        vm.removeDiagnosis(existingResult)

        _ = try vm.update(session, in: context)

        #expect(session.diagnoses?.count == 0)
    }

    // MARK: - Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaV4.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
