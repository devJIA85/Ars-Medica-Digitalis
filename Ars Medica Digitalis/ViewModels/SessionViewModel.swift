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
    var sessionType: String = SessionTypeMapping.presencial.rawValue
    var durationMinutes: Int = 50
    var chiefComplaint: String = ""
    var notes: String = ""
    var treatmentPlan: String = ""
    var status: String = SessionStatusMapping.completada.rawValue

    /// Flag interno para evitar ajustar el status al cargar datos
    /// de una sesión existente (modo edición).
    private var isLoadingFromSession = false

    /// Diagnósticos seleccionados como DTOs de la API.
    /// Se convierten a modelos Diagnosis de SwiftData al guardar la sesión.
    var selectedDiagnoses: [ICD11SearchResult] = []
    /// Solo se activa cuando el profesional agrega o quita diagnósticos
    /// manualmente en el formulario.
    private var didModifyDiagnoses: Bool = false

    // MARK: - Init

    /// Init por defecto: sessionDate = ahora, status = completada.
    init() {}

    /// Init con fecha inicial (ej: día seleccionado en calendario + hora actual).
    /// Ajusta el status automáticamente según si la fecha es futura.
    init(initialDate: Date) {
        self.sessionDate = initialDate
        // Ajustar status coherente con la fecha recibida
        if initialDate > Date() {
            self.status = SessionStatusMapping.programada.rawValue
        }
    }

    // MARK: - Validación

    /// El motivo de consulta es el campo mínimo obligatorio para una sesión.
    var canSave: Bool {
        !chiefComplaint.trimmed.isEmpty
    }

    // MARK: - Opciones para Pickers

    static let sessionTypes = [
        (SessionTypeMapping.presencial.rawValue, SessionTypeMapping.presencial.label),
        (SessionTypeMapping.videollamada.rawValue, SessionTypeMapping.videollamada.label),
        (SessionTypeMapping.telefonica.rawValue, SessionTypeMapping.telefonica.label)
    ]

    static let sessionStatuses = [
        (SessionStatusMapping.programada.rawValue, SessionStatusMapping.programada.label),
        (SessionStatusMapping.completada.rawValue, SessionStatusMapping.completada.label),
        (SessionStatusMapping.cancelada.rawValue, SessionStatusMapping.cancelada.label)
    ]

    // MARK: - Ajuste automático de status

    /// Cuando el usuario cambia la fecha, el status se ajusta:
    /// futuro → "programada", pasado/hoy → "completada".
    /// Solo aplica si el status actual era uno de estos dos automáticos,
    /// para no sobreescribir "cancelada" elegida manualmente.
    private func adjustStatusForDate() {
        let isFuture = sessionDate > Date()
        let current = SessionStatusMapping(sessionStatusRawValue: status) ?? .completada

        if isFuture && current == .completada {
            status = SessionStatusMapping.programada.rawValue
        } else if !isFuture && current == .programada {
            status = SessionStatusMapping.completada.rawValue
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

        selectedDiagnoses = active.map(\.asSearchResult)
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
        selectedDiagnoses = (session.diagnoses ?? []).map(\.asSearchResult)
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
            notes: notes.trimmed,
            chiefComplaint: chiefComplaint.trimmed,
            treatmentPlan: treatmentPlan.trimmed,
            status: status,
            patient: patient
        )
        context.insert(session)

        // Snapshot inmutable de cada diagnóstico CIE-11 seleccionado
        for result in selectedDiagnoses {
            let diagnosis = Diagnosis(from: result, session: session)
            context.insert(diagnosis)
        }

        // Sincronizar diagnósticos vigentes del paciente con los de esta sesión.
        // Solo cuando hubo cambios explícitos en diagnósticos durante esta edición.
        if didModifyDiagnoses {
            syncActiveDiagnoses(for: patient, in: context)
        }
    }

    // MARK: - Actualización

    /// Actualiza una Session existente. Los diagnósticos se gestionan por
    /// diferencia: se eliminan los que ya no están y se crean los nuevos.
    /// Sincroniza diagnósticos vigentes del paciente si es la sesión más reciente.
    func update(_ session: Session, in context: ModelContext) {
        session.sessionDate = sessionDate
        session.sessionType = sessionType
        session.durationMinutes = durationMinutes
        session.notes = notes.trimmed
        session.chiefComplaint = chiefComplaint.trimmed
        session.treatmentPlan = treatmentPlan.trimmed
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
            let diagnosis = Diagnosis(from: result, session: session)
            context.insert(diagnosis)
        }

        // Sincronizar vigentes si esta es la sesión más reciente completada
        if didModifyDiagnoses, let patient = session.patient {
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
            let diagnosis = Diagnosis(from: result, patient: patient)
            context.insert(diagnosis)
        }

        patient.updatedAt = Date()
    }

    // MARK: - Gestión de diagnósticos

    func addDiagnosis(_ result: ICD11SearchResult) {
        guard !selectedDiagnoses.contains(where: { $0.id == result.id }) else { return }
        selectedDiagnoses.append(result)
        didModifyDiagnoses = true
    }

    func removeDiagnosis(_ result: ICD11SearchResult) {
        selectedDiagnoses.removeAll { $0.id == result.id }
        didModifyDiagnoses = true
    }
}
