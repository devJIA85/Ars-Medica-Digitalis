//
//  ProfessionalViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para la creación y edición del perfil profesional.
//  Usa @Observable (no ObservableObject) según las reglas del proyecto.
//

import Foundation
import SwiftData

@Observable
final class ProfessionalViewModel {

    // Campos editables del formulario
    var fullName: String = ""
    var licenseNumber: String = ""
    var specialty: String = ""
    var email: String = ""
    var defaultPatientCurrencyCode: String = ""
    var defaultFinancialSessionTypeID: UUID? = nil

    // Validación mínima para habilitar el botón de guardar
    var canSave: Bool {
        !fullName.trimmed.isEmpty
        && !specialty.trimmed.isEmpty
        && !licenseNumber.trimmed.isEmpty
    }

    // Carga los datos de un Professional existente para edición
    func load(from professional: Professional) {
        fullName = professional.fullName
        licenseNumber = professional.licenseNumber
        specialty = professional.specialty
        email = professional.email
        defaultPatientCurrencyCode = professional.defaultPatientCurrencyCode
        defaultFinancialSessionTypeID = professional.defaultFinancialSessionTypeID
    }

    // Crea un nuevo Professional y lo inserta en el contexto
    func createProfessional(in context: ModelContext) {
        let normalizedCurrencyCode = defaultPatientCurrencyCode.trimmed.uppercased()

        let professional = Professional(
            fullName: fullName.trimmed,
            licenseNumber: licenseNumber.trimmed,
            specialty: specialty.trimmed,
            email: email.trimmed,
            defaultPatientCurrencyCode: normalizedCurrencyCode,
            defaultFinancialSessionTypeID: defaultFinancialSessionTypeID
        )
        context.insert(professional)
    }

    // Actualiza un Professional existente con los valores del formulario
    func update(_ professional: Professional) {
        let normalizedCurrencyCode = defaultPatientCurrencyCode.trimmed.uppercased()

        professional.fullName = fullName.trimmed
        professional.licenseNumber = licenseNumber.trimmed
        professional.specialty = specialty.trimmed
        professional.email = email.trimmed
        professional.defaultPatientCurrencyCode = normalizedCurrencyCode
        professional.defaultFinancialSessionTypeID = defaultFinancialSessionTypeID
        professional.updatedAt = Date()
    }
}
