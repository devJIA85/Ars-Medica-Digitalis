//
//  Diagnosis.swift
//  Ars Medica Digitalis
//
//  Diagnóstico CIE-11 con doble uso:
//  1. Snapshot inmutable en sesión: cada Session tiene sus propios Diagnosis
//     que registran el diagnóstico al momento de la consulta.
//  2. Diagnóstico vigente del paciente: Patient.activeDiagnoses mantiene
//     los diagnósticos actuales editables directamente desde el perfil.
//
//  Desnormalización intencional: guardar código, título y URI directamente
//  asegura que un diagnóstico de 2025 sea legible en 2035, independientemente
//  de cambios en la API del CIE-11.
//

import Foundation
import SwiftData

// MARK: - DiagnosisType

/// Clasificación clínica de un diagnóstico CIE-11.
///
/// Los rawValues son los strings canónicos almacenados en SwiftData,
/// iguales a los valores históricos — ningún registro existente requiere migración.
///
/// El enum es `CaseIterable` para construir pickers sin hardcodear arrays;
/// `Codable` para ser serializable; `Sendable` para uso seguro en actores.
enum DiagnosisType: String, Codable, CaseIterable, Sendable {
    /// Diagnóstico de mayor peso clínico para esta sesión o paciente.
    case principal
    /// Diagnóstico acompañante, comórbido o de menor jerarquía.
    case secundario
    /// Diagnóstico provisional pendiente de confirmación diferencial.
    case diferencial

    /// Etiqueta localizada para mostrar en UI e informes.
    var label: String {
        switch self {
        case .principal:   "Principal"
        case .secundario:  "Secundario"
        case .diferencial: "Diferencial"
        }
    }

    /// Verdadero solo para `.principal` — evita comparaciones de strings dispersas.
    var isPrimary: Bool { self == .principal }

    /// Decodifica un string almacenado, con fallback seguro a `.principal`.
    /// Protege contra valores legados o corruptos sin crash en runtime.
    static func from(_ rawValue: String) -> DiagnosisType {
        DiagnosisType(rawValue: rawValue.lowercased()) ?? .principal
    }
}

// MARK: - Diagnosis

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
    /// Capítulo CIE-11 al que pertenece el código (ej: "06" = Trastornos mentales).
    /// Capturado del resultado de búsqueda para navegación y agrupación futura.
    var icdChapter: String = ""

    // Contexto clínico.
    // diagnosisType se persiste como String (rawValue) para compatibilidad SwiftData/CloudKit.
    // Usar `diagnosisTypeValue` en toda la lógica de dominio para acceso tipado.
    var diagnosisType: String = DiagnosisType.principal.rawValue
    var severity: String = ""
    var clinicalNotes: String = ""      // ⚠️ CRÍTICO — contenido clínico

    var diagnosedAt: Date = Date()
    var createdAt: Date = Date()

    // Relaciones opcionales por requisito CloudKit.
    // Un Diagnosis pertenece a una Session (snapshot histórico)
    // O a un Patient (diagnóstico vigente editable desde el perfil).
    // Ambas son opcionales — nunca se usan simultáneamente.
    var session: Session? = nil
    var patient: Patient? = nil

    // MARK: - Typed accessor

    /// API tipada sobre el campo persistido `diagnosisType`.
    ///
    /// Mismo patrón que `Session.sessionTypeValue` / `sessionStatusValue`:
    /// la persistencia usa String (backward compat con CloudKit),
    /// la lógica de dominio usa el enum para type safety total.
    var diagnosisTypeValue: DiagnosisType {
        get { DiagnosisType.from(diagnosisType) }
        set { diagnosisType = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        icdCode: String = "",
        icdTitle: String = "",
        icdTitleEs: String = "",
        icdURI: String = "",
        icdVersion: String = "2024-01",
        icdChapter: String = "",
        diagnosisType: DiagnosisType = .principal,
        severity: String = "",
        clinicalNotes: String = "",
        diagnosedAt: Date = Date(),
        createdAt: Date = Date(),
        session: Session? = nil,
        patient: Patient? = nil
    ) {
        self.id = id
        self.icdCode = icdCode
        self.icdTitle = icdTitle
        self.icdTitleEs = icdTitleEs
        self.icdURI = icdURI
        self.icdVersion = icdVersion
        self.icdChapter = icdChapter
        self.diagnosisType = diagnosisType.rawValue
        self.severity = severity
        self.clinicalNotes = clinicalNotes
        self.diagnosedAt = diagnosedAt
        self.createdAt = createdAt
        self.session = session
        self.patient = patient
    }
}

extension Diagnosis {
    /// Título preferido para mostrar en UI/reportes:
    /// español si existe, sino fallback al título base.
    var displayTitle: String {
        icdTitleEs.isEmpty ? icdTitle : icdTitleEs
    }

    /// Conversión estandarizada a DTO de búsqueda CIE-11 para reutilizar
    /// en formularios y precargas de diagnósticos.
    var asSearchResult: ICD11SearchResult {
        ICD11SearchResult(
            id: icdURI,
            theCode: icdCode.isEmpty ? nil : icdCode,
            title: displayTitle,
            chapter: nil,
            score: nil
        )
    }

    /// Factory desde un resultado CIE-11 para persistir snapshot clínico.
    ///
    /// Captura todos los campos disponibles del DTO para máxima preservación histórica.
    /// El tipo de diagnóstico debe asignarse por el contexto de llamada
    /// (`.principal` si es el primero, `.secundario` en adelante).
    convenience init(
        from result: ICD11SearchResult,
        diagnosisType: DiagnosisType = .principal,
        session: Session? = nil,
        patient: Patient? = nil
    ) {
        self.init(
            icdCode: result.theCode ?? "",
            icdTitle: result.title,
            icdTitleEs: result.title,
            icdURI: result.id,
            icdVersion: "2024-01",
            icdChapter: result.chapter ?? "",
            diagnosisType: diagnosisType,
            session: session,
            patient: patient
        )
    }
}
