//
//  Hospitalization.swift
//  Ars Medica Digitalis
//
//  Internación previa del paciente.
//  Registra hospitalizaciones anteriores con fecha,
//  duración y observaciones clínicas relevantes.
//  Cada paciente puede tener múltiples internaciones.
//

import Foundation
import SwiftData

@Model
final class Hospitalization {

    var id: UUID = UUID()

    // Fecha de ingreso a la internación
    var admissionDate: Date = Date()

    // Duración aproximada (texto libre)
    var durationDescription: String = ""    // Ej: "15 días", "3 semanas"

    // Motivo y detalles de la internación
    var observations: String = ""

    var createdAt: Date = Date()

    // Relación opcional por requisito CloudKit
    var patient: Patient? = nil

    init(
        id: UUID = UUID(),
        admissionDate: Date = Date(),
        durationDescription: String = "",
        observations: String = "",
        createdAt: Date = Date(),
        patient: Patient? = nil
    ) {
        self.id = id
        self.admissionDate = admissionDate
        self.durationDescription = durationDescription
        self.observations = observations
        self.createdAt = createdAt
        self.patient = patient
    }
}
