//
//  Diagnosis.swift
//  Ars Medica Digitalis
//
//  Diagnóstico CIE-11 asociado a una sesión.
//  Los datos del código se persisten como snapshot inmutable al momento del diagnóstico,
//  garantizando legibilidad histórica sin dependencia de la API externa.
//
//  Desnormalización intencional: guardar código, título y URI directamente
//  asegura que un diagnóstico de 2025 sea legible en 2035, independientemente
//  de cambios en la API del CIE-11.
//

import Foundation
import SwiftData

@Model
final class Diagnosis {

    var id: UUID = UUID()

    // Snapshot CIE-11 — inmutable una vez guardado.
    // icdVersion permite saber qué release de la clasificación se usó,
    // ya que los códigos pueden cambiar de descripción entre versiones.
    var icdCode: String = ""            // Ej: "6A70"
    var icdTitle: String = ""           // Ej: "Single episode depressive disorder"
    var icdTitleEs: String = ""         // Título en español si disponible
    var icdURI: String = ""             // URI canónico del WHO
    var icdVersion: String = "2024-01"  // Release del CIE-11 usado al diagnosticar

    // Contexto clínico
    var diagnosisType: String = "principal"  // "principal" | "secundario" | "diferencial"
    var severity: String = ""
    var clinicalNotes: String = ""      // ⚠️ CRÍTICO — contenido clínico

    var diagnosedAt: Date = Date()
    var createdAt: Date = Date()

    // Relación opcional por requisito CloudKit
    var session: Session? = nil

    init(
        id: UUID = UUID(),
        icdCode: String = "",
        icdTitle: String = "",
        icdTitleEs: String = "",
        icdURI: String = "",
        icdVersion: String = "2024-01",
        diagnosisType: String = "principal",
        severity: String = "",
        clinicalNotes: String = "",
        diagnosedAt: Date = Date(),
        createdAt: Date = Date(),
        session: Session? = nil
    ) {
        self.id = id
        self.icdCode = icdCode
        self.icdTitle = icdTitle
        self.icdTitleEs = icdTitleEs
        self.icdURI = icdURI
        self.icdVersion = icdVersion
        self.diagnosisType = diagnosisType
        self.severity = severity
        self.clinicalNotes = clinicalNotes
        self.diagnosedAt = diagnosedAt
        self.createdAt = createdAt
        self.session = session
    }
}
