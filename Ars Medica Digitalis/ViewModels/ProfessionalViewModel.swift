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

    // Validación mínima para habilitar el botón de guardar
    var canSave: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        && !specialty.trimmingCharacters(in: .whitespaces).isEmpty
        && !licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Carga los datos de un Professional existente para edición
    func load(from professional: Professional) {
        fullName = professional.fullName
        licenseNumber = professional.licenseNumber
        specialty = professional.specialty
        email = professional.email
    }

    // Crea un nuevo Professional y lo inserta en el contexto
    func createProfessional(in context: ModelContext) {
        let professional = Professional(
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            licenseNumber: licenseNumber.trimmingCharacters(in: .whitespaces),
            specialty: specialty.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces)
        )
        context.insert(professional)
    }

    // Actualiza un Professional existente con los valores del formulario
    func update(_ professional: Professional) {
        professional.fullName = fullName.trimmingCharacters(in: .whitespaces)
        professional.licenseNumber = licenseNumber.trimmingCharacters(in: .whitespaces)
        professional.specialty = specialty.trimmingCharacters(in: .whitespaces)
        professional.email = email.trimmingCharacters(in: .whitespaces)
        professional.updatedAt = Date()
    }
}
