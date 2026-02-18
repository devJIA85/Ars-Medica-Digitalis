//
//  Patient.swift
//  Ars Medica Digitalis
//
//  Sujeto central de la historia clínica.
//  Implementa borrado lógico mediante deletedAt — nunca se elimina físicamente
//  porque la historia clínica es un documento médico-legal.
//

import Foundation
import SwiftData

@Model
final class Patient {

    var id: UUID = UUID()

    // Datos demográficos
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Date()
    var biologicalSex: String = ""   // String en lugar de enum para compatibilidad CloudKit
    var nationalId: String = ""      // ⚠️ CRÍTICO — dato de identidad sensible
    var email: String = ""           // ⚠️ Sensible
    var phoneNumber: String = ""     // ⚠️ Sensible
    var address: String = ""

    // BORRADO LÓGICO: cuando deletedAt != nil, el paciente está inactivo.
    // El #Predicate filtra { $0.deletedAt == nil } en la vista principal.
    // CloudKit conserva el registro histórico sin excepción.
    var deletedAt: Date? = nil

    // Trazabilidad
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relaciones opcionales por requisito CloudKit
    var professional: Professional? = nil

    @Relationship(deleteRule: .cascade, inverse: \Session.patient)
    var sessions: [Session]? = []

    // Computed properties — no se persisten, solo para la UI
    var fullName: String { "\(firstName) \(lastName)" }
    var isActive: Bool { deletedAt == nil }

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        dateOfBirth: Date = Date(),
        biologicalSex: String = "",
        nationalId: String = "",
        email: String = "",
        phoneNumber: String = "",
        address: String = "",
        deletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        professional: Professional? = nil,
        sessions: [Session]? = []
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
        self.nationalId = nationalId
        self.email = email
        self.phoneNumber = phoneNumber
        self.address = address
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.professional = professional
        self.sessions = sessions
    }
}
