//
//  PriorTreatment.swift
//  Ars Medica Digitalis
//
//  Antecedente de tratamiento previo del paciente.
//  Registra terapias, tratamientos psiquiátricos u otros
//  realizados antes de la atención con el profesional actual.
//  Cada paciente puede tener múltiples tratamientos previos.
//

import Foundation
import SwiftData

@Model
final class PriorTreatment {

    var id: UUID = UUID()

    // Tipo de tratamiento realizado
    var treatmentType: String = ""          // "psicoterapia" | "psiquiatría" | "otro"

    // Duración aproximada del tratamiento (texto libre)
    var durationDescription: String = ""    // Ej: "2 años", "6 meses"

    // Medicación utilizada durante el tratamiento
    var medication: String = ""

    // Resultado del tratamiento
    var outcome: String = ""                // "alta" | "abandono" | "derivación" | "en curso" | "otro"

    // Observaciones adicionales
    var observations: String = ""

    var createdAt: Date = Date()

    // Relación opcional por requisito CloudKit
    var patient: Patient? = nil

    init(
        id: UUID = UUID(),
        treatmentType: String = "",
        durationDescription: String = "",
        medication: String = "",
        outcome: String = "",
        observations: String = "",
        createdAt: Date = Date(),
        patient: Patient? = nil
    ) {
        self.id = id
        self.treatmentType = treatmentType
        self.durationDescription = durationDescription
        self.medication = medication
        self.outcome = outcome
        self.observations = observations
        self.createdAt = createdAt
        self.patient = patient
    }
}
