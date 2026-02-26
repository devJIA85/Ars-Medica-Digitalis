//
//  Session.swift
//  Ars Medica Digitalis
//
//  Cada encuentro clínico entre el profesional y el paciente.
//  El campo notes es el corazón narrativo de la historia clínica.
//

import Foundation
import SwiftData

@Model
final class Session {

    var id: UUID = UUID()

    var sessionDate: Date = Date()
    var sessionType: String = SessionTypeMapping.presencial.rawValue   // "presencial" | "videollamada" | "telefónica"
    var durationMinutes: Int = 50
    var notes: String = ""                   // ⚠️ CRÍTICO — contenido clínico privado
    var chiefComplaint: String = ""          // Motivo de consulta
    var treatmentPlan: String = ""
    var status: String = SessionStatusMapping.completada.rawValue      // "programada" | "completada" | "cancelada"

    // Trazabilidad
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relaciones opcionales por requisito CloudKit
    var patient: Patient? = nil

    @Relationship(deleteRule: .cascade, inverse: \Diagnosis.session)
    var diagnoses: [Diagnosis]? = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.session)
    var attachments: [Attachment]? = []

    /// Acceso tipado para modalidad sin romper compatibilidad de persistencia.
    var sessionTypeValue: SessionTypeMapping {
        get { SessionTypeMapping(sessionTypeRawValue: sessionType) ?? .presencial }
        set { sessionType = newValue.rawValue }
    }

    /// Acceso tipado para estado sin romper compatibilidad de persistencia.
    var sessionStatusValue: SessionStatusMapping {
        get { SessionStatusMapping(sessionStatusRawValue: status) ?? .completada }
        set { status = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        sessionDate: Date = Date(),
        sessionType: String = SessionTypeMapping.presencial.rawValue,
        durationMinutes: Int = 50,
        notes: String = "",
        chiefComplaint: String = "",
        treatmentPlan: String = "",
        status: String = SessionStatusMapping.completada.rawValue,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        patient: Patient? = nil,
        diagnoses: [Diagnosis]? = [],
        attachments: [Attachment]? = []
    ) {
        self.id = id
        self.sessionDate = sessionDate
        self.sessionType = sessionType
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.chiefComplaint = chiefComplaint
        self.treatmentPlan = treatmentPlan
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.patient = patient
        self.diagnoses = diagnoses
        self.attachments = attachments
    }
}
