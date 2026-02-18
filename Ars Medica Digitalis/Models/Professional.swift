//
//  Professional.swift
//  Ars Medica Digitalis
//
//  Representa al profesional de salud propietario de la cuenta.
//  Es el anchor de todos los datos: todo viaja en su zona privada de CloudKit.
//

import Foundation
import SwiftData

@Model
final class Professional {

    // UUID generado en cliente para coherencia de identidad entre dispositivos,
    // antes de que CloudKit asigne su propio recordName.
    var id: UUID = UUID()

    // Datos de identidad profesional
    var fullName: String = ""
    var licenseNumber: String = ""   // ⚠️ Sensible — protegido por zona privada iCloud
    var specialty: String = ""       // Ej: "Psicología", "Odontología"
    var email: String = ""           // ⚠️ Sensible

    // Configuración regional para la API CIE-11 (Accept-Language header)
    var preferredLanguage: String = "es"

    // Trazabilidad: auditoría clínica y resolución de conflictos de sincronización
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relación opcional por requisito de CloudKit: puede descargar hijos antes que padres.
    // En la lógica de negocio, un Professional siempre tiene patients (nunca nil en práctica).
    @Relationship(deleteRule: .cascade, inverse: \Patient.professional)
    var patients: [Patient]? = []

    init(
        id: UUID = UUID(),
        fullName: String = "",
        licenseNumber: String = "",
        specialty: String = "",
        email: String = "",
        preferredLanguage: String = "es",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        patients: [Patient]? = []
    ) {
        self.id = id
        self.fullName = fullName
        self.licenseNumber = licenseNumber
        self.specialty = specialty
        self.email = email
        self.preferredLanguage = preferredLanguage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.patients = patients
    }
}
