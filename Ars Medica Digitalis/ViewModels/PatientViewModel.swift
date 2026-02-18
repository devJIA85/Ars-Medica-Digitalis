//
//  PatientViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para alta, edición y baja lógica de pacientes (HU-02, HU-03).
//

import Foundation
import SwiftData

@Observable
final class PatientViewModel {

    // Campos editables del formulario
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Date()
    var biologicalSex: String = ""
    var nationalId: String = ""
    var email: String = ""
    var phoneNumber: String = ""
    var address: String = ""

    // Validación mínima: nombre y apellido son obligatorios (HU-02)
    var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Carga datos de un Patient existente para edición
    func load(from patient: Patient) {
        firstName = patient.firstName
        lastName = patient.lastName
        dateOfBirth = patient.dateOfBirth
        biologicalSex = patient.biologicalSex
        nationalId = patient.nationalId
        email = patient.email
        phoneNumber = patient.phoneNumber
        address = patient.address
    }

    // Crea un nuevo Patient vinculado al Professional activo
    func createPatient(for professional: Professional, in context: ModelContext) {
        let patient = Patient(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            nationalId: nationalId.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces),
            address: address.trimmingCharacters(in: .whitespaces),
            professional: professional
        )
        context.insert(patient)
    }

    // Actualiza un Patient existente con los valores del formulario
    func update(_ patient: Patient) {
        patient.firstName = firstName.trimmingCharacters(in: .whitespaces)
        patient.lastName = lastName.trimmingCharacters(in: .whitespaces)
        patient.dateOfBirth = dateOfBirth
        patient.biologicalSex = biologicalSex
        patient.nationalId = nationalId.trimmingCharacters(in: .whitespaces)
        patient.email = email.trimmingCharacters(in: .whitespaces)
        patient.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
        patient.address = address.trimmingCharacters(in: .whitespaces)
        patient.updatedAt = Date()
    }

    // Baja lógica: marca deletedAt con la fecha actual (HU-03).
    // La historia clínica permanece íntegra en CloudKit.
    func softDelete(_ patient: Patient) {
        patient.deletedAt = Date()
        patient.updatedAt = Date()
    }

    // Restaurar un paciente dado de baja
    func restore(_ patient: Patient) {
        patient.deletedAt = nil
        patient.updatedAt = Date()
    }
}
