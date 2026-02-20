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

    var sessionDate: Date = Date() {
        didSet {
            // Si la fecha pasa a futuro y el status no fue editado manualmente,
            // cambiar automáticamente a "programada" (y viceversa).
            if !isLoadingFromSession {
                adjustStatusForDate()
            }
        }
    }
    var sessionType: String = "presencial"
    var durationMinutes: Int = 50
    var chiefComplaint: String = ""
    var notes: String = ""
    var treatmentPlan: String = ""
    var status: String = "completada"

    /// Flag interno para evitar ajustar el status al cargar datos
    /// de una sesión existente (modo edición).
    private var isLoadingFromSession = false

    /// Diagnósticos seleccionados como DTOs de la API.
    /// Se convierten a modelos Diagnosis de SwiftData al guardar la sesión.
    var selectedDiagnoses: [ICD11SearchResult] = []

    // MARK: - Init

    /// Init por defecto: sessionDate = ahora, status = completada.
    init() {}

    /// Init con fecha inicial (ej: día seleccionado en calendario + hora actual).
    /// Ajusta el status automáticamente según si la fecha es futura.
    init(initialDate: Date) {
        self.sessionDate = initialDate
        // Ajustar status coherente con la fecha recibida
        if initialDate > Date() {
            self.status = "programada"
        }
    }

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

    // MARK: - Ajuste automático de status

    /// Cuando el usuario cambia la fecha, el status se ajusta:
    /// futuro → "programada", pasado/hoy → "completada".
    /// Solo aplica si el status actual era uno de estos dos automáticos,
    /// para no sobreescribir "cancelada" elegida manualmente.
    private func adjustStatusForDate() {
        let isFuture = sessionDate > Date()
        if isFuture && status == "completada" {
            status = "programada"
        } else if !isFuture && status == "programada" {
            status = "completada"
        }
    }

    // MARK: - Pre-carga de diagnósticos vigentes (modo alta)

    /// Al crear una nueva sesión, carga automáticamente los diagnósticos
    /// vigentes del paciente (Patient.activeDiagnoses). Así el profesional
    /// no tiene que re-seleccionar diagnósticos crónicos en cada consulta —
    /// solo cambia los que necesite.
    func preloadDiagnoses(from patient: Patient) {
        guard selectedDiagnoses.isEmpty else { return }

        let active = patient.activeDiagnoses ?? []
        guard !active.isEmpty else { return }

        selectedDiagnoses = active.map { diagnosis in
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
        isLoadingFromSession = true
        defer { isLoadingFromSession = false }

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
    /// Además sincroniza los diagnósticos vigentes del paciente.
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

        // Sincronizar diagnósticos vigentes del paciente con los de esta sesión.
        // Si el profesional cambió los diagnósticos en el formulario,
        // el perfil del paciente refleja el cuadro actualizado.
        syncActiveDiagnoses(for: patient, in: context)
    }

    // MARK: - Actualización

    /// Actualiza una Session existente. Los diagnósticos se gestionan por
    /// diferencia: se eliminan los que ya no están y se crean los nuevos.
    /// Sincroniza diagnósticos vigentes del paciente si es la sesión más reciente.
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

        // Sincronizar vigentes si esta es la sesión más reciente completada
        if let patient = session.patient {
            syncActiveDiagnoses(for: patient, in: context)
        }
    }

    // MARK: - Sincronización de diagnósticos vigentes

    /// Reemplaza los diagnósticos vigentes del paciente con los seleccionados
    /// en el formulario. Usa reconciliación por URI para minimizar escrituras.
    private func syncActiveDiagnoses(for patient: Patient, in context: ModelContext) {
        let currentActive = patient.activeDiagnoses ?? []
        let selectedURIs = Set(selectedDiagnoses.map(\.id))
        let activeURIs = Set(currentActive.map(\.icdURI))

        // Eliminar los que ya no están en la selección
        for existing in currentActive where !selectedURIs.contains(existing.icdURI) {
            context.delete(existing)
        }

        // Agregar los nuevos que no existen como vigentes
        for result in selectedDiagnoses where !activeURIs.contains(result.id) {
            let diagnosis = Diagnosis(
                icdCode: result.theCode ?? "",
                icdTitle: result.title,
                icdTitleEs: result.title,
                icdURI: result.id,
                icdVersion: "2024-01",
                patient: patient
            )
            context.insert(diagnosis)
        }

        patient.updatedAt = Date()
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
