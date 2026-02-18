//
//  SessionViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para alta y edición de sesiones clínicas (HU-04).
//  Gestiona los campos del formulario y la lista de diagnósticos
//  seleccionados desde la búsqueda CIE-11.
//

import Foundation
import SwiftData

@Observable
final class SessionViewModel {

    // MARK: - Campos editables del formulario

    var sessionDate: Date = Date()
    var sessionType: String = "presencial"
    var durationMinutes: Int = 50
    var chiefComplaint: String = ""
    var notes: String = ""
    var treatmentPlan: String = ""
    var status: String = "completada"

    /// Diagnósticos seleccionados como DTOs de la API.
    /// Se convierten a modelos Diagnosis de SwiftData al guardar la sesión.
    var selectedDiagnoses: [ICD11SearchResult] = []

    // MARK: - Validación

    /// El motivo de consulta es el campo mínimo obligatorio para una sesión.
    var canSave: Bool {
        !chiefComplaint.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Opciones para Pickers

    static let sessionTypes = [
        ("presencial", "Presencial"),
        ("videollamada", "Videollamada"),
        ("telefónica", "Telefónica")
    ]

    static let sessionStatuses = [
        ("programada", "Programada"),
        ("completada", "Completada"),
        ("cancelada", "Cancelada")
    ]

    // MARK: - Pre-carga de diagnósticos vigentes (modo alta)

    /// Al crear una nueva sesión, carga automáticamente los diagnósticos
    /// de la última sesión completada del paciente. Así el profesional no
    /// tiene que re-seleccionar diagnósticos crónicos en cada consulta —
    /// solo cambia los que necesite.
    func preloadDiagnoses(from patient: Patient) {
        guard selectedDiagnoses.isEmpty else { return }

        let lastCompleted = (patient.sessions ?? [])
            .filter { $0.status == "completada" }
            .sorted { $0.sessionDate > $1.sessionDate }
            .first

        guard let diagnoses = lastCompleted?.diagnoses, !diagnoses.isEmpty else { return }

        selectedDiagnoses = diagnoses.map { diagnosis in
            ICD11SearchResult(
                id: diagnosis.icdURI,
                theCode: diagnosis.icdCode.isEmpty ? nil : diagnosis.icdCode,
                title: diagnosis.icdTitleEs.isEmpty
                    ? diagnosis.icdTitle
                    : diagnosis.icdTitleEs,
                chapter: nil,
                score: nil
            )
        }
    }

    // MARK: - Carga (modo edición)

    /// Carga datos de una Session existente para edición.
    func load(from session: Session) {
        sessionDate = session.sessionDate
        sessionType = session.sessionType
        durationMinutes = session.durationMinutes
        chiefComplaint = session.chiefComplaint
        notes = session.notes
        treatmentPlan = session.treatmentPlan
        status = session.status

        // Reconstruir DTOs desde los Diagnosis persistidos para que la UI
        // muestre los diagnósticos sin necesidad de llamar a la API.
        selectedDiagnoses = (session.diagnoses ?? []).map { diagnosis in
            ICD11SearchResult(
                id: diagnosis.icdURI,
                theCode: diagnosis.icdCode.isEmpty ? nil : diagnosis.icdCode,
                title: diagnosis.icdTitleEs.isEmpty
                    ? diagnosis.icdTitle
                    : diagnosis.icdTitleEs,
                chapter: nil,
                score: nil
            )
        }
    }

    // MARK: - Creación

    /// Crea una nueva Session vinculada al paciente y persiste los
    /// diagnósticos seleccionados como snapshots inmutables.
    func createSession(for patient: Patient, in context: ModelContext) {
        let session = Session(
            sessionDate: sessionDate,
            sessionType: sessionType,
            durationMinutes: durationMinutes,
            notes: notes.trimmingCharacters(in: .whitespaces),
            chiefComplaint: chiefComplaint.trimmingCharacters(in: .whitespaces),
            treatmentPlan: treatmentPlan.trimmingCharacters(in: .whitespaces),
            status: status,
            patient: patient
        )
        context.insert(session)

        // Snapshot inmutable de cada diagnóstico CIE-11 seleccionado
        for result in selectedDiagnoses {
            let diagnosis = Diagnosis(
                icdCode: result.theCode ?? "",
                icdTitle: result.title,
                icdTitleEs: result.title,
                icdURI: result.id,
                icdVersion: "2024-01",
                session: session
            )
            context.insert(diagnosis)
        }
    }

    // MARK: - Actualización

    /// Actualiza una Session existente. Los diagnósticos se gestionan por
    /// diferencia: se eliminan los que ya no están y se crean los nuevos.
    func update(_ session: Session, in context: ModelContext) {
        session.sessionDate = sessionDate
        session.sessionType = sessionType
        session.durationMinutes = durationMinutes
        session.notes = notes.trimmingCharacters(in: .whitespaces)
        session.chiefComplaint = chiefComplaint.trimmingCharacters(in: .whitespaces)
        session.treatmentPlan = treatmentPlan.trimmingCharacters(in: .whitespaces)
        session.status = status
        session.updatedAt = Date()

        // Reconciliar diagnósticos: eliminar los que ya no están seleccionados
        let existingDiagnoses = session.diagnoses ?? []
        let selectedURIs = Set(selectedDiagnoses.map(\.id))

        for existing in existingDiagnoses {
            if !selectedURIs.contains(existing.icdURI) {
                context.delete(existing)
            }
        }

        // Agregar diagnósticos nuevos
        let existingURIs = Set(existingDiagnoses.map(\.icdURI))
        for result in selectedDiagnoses where !existingURIs.contains(result.id) {
            let diagnosis = Diagnosis(
                icdCode: result.theCode ?? "",
                icdTitle: result.title,
                icdTitleEs: result.title,
                icdURI: result.id,
                icdVersion: "2024-01",
                session: session
            )
            context.insert(diagnosis)
        }
    }

    // MARK: - Gestión de diagnósticos

    func addDiagnosis(_ result: ICD11SearchResult) {
        guard !selectedDiagnoses.contains(where: { $0.id == result.id }) else { return }
        selectedDiagnoses.append(result)
    }

    func removeDiagnosis(_ result: ICD11SearchResult) {
        selectedDiagnoses.removeAll { $0.id == result.id }
    }
}
