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

/// Intención de pago elegida por la UI antes de persistir movimientos.
/// Se separa de la ejecución real para validar la decisión del usuario
/// antes de escribir Payment y evitar lógica financiera en la vista.
enum PaymentIntent: Sendable {
    case full
    case partial(Decimal)
    case none
}

/// Borrador in-memory para la sheet de finalización.
/// Expone el importe pendiente y la moneda ya resueltos sin crear todavía
/// ningún Payment, de modo que la UI pueda decidir cómo cerrar la sesión.
struct CompletionDraft: Sendable {
    let sessionID: UUID
    let amountDue: Decimal
    let currencyCode: String
    let isCourtesy: Bool
    let configurationIssue: CompletionConfigurationIssue?

    var isFinanciallyConfigured: Bool {
        configurationIssue == nil
    }
}

/// Snapshot liviano para mostrar el resumen financiero dentro del formulario.
/// Se calcula on-demand para que la UI vea precio y moneda estimados antes
/// de completar la sesión, sin persistir nada ni duplicar lógica en la vista.
struct SessionPricingPreview: Sendable {
    let amount: Decimal
    let currencyCode: String
    let isCourtesy: Bool
    let configurationIssue: CompletionConfigurationIssue?

    var isResolved: Bool {
        configurationIssue == nil
    }
}

/// Explica por qué una sesión todavía no puede cerrarse financieramente.
/// Se expone al sheet para evitar UI engañosa cuando falta configuración base.
enum CompletionConfigurationIssue: Sendable, Equatable {
    case missingFinancialSessionType
    case missingPatientCurrency
    case missingResolvedPrice

    var message: String {
        switch self {
        case .missingFinancialSessionType:
            return "Elegí un tipo facturable en la sesión antes de completarla."
        case .missingPatientCurrency:
            return "Configurá la moneda predeterminada en Paciente > Editar > Finanzas antes de completar la sesión."
        case .missingResolvedPrice:
            return "Definí un honorario vigente en Perfil > Honorarios para este tipo de sesión antes de completar."
        }
    }
}

/// Errores controlados del flujo de cierre financiero.
/// Se usan para dar feedback claro cuando la UI intenta cerrar
/// una sesión con una intención de pago inválida.
enum SessionCompletionError: LocalizedError {
    case sessionAlreadyCompleted
    case invalidPartialAmount
    case missingFinancialSessionType
    case missingPatientCurrency
    case missingResolvedPrice

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyCompleted:
            return "La sesión ya estaba completada."
        case .invalidPartialAmount:
            return "Ingresá un monto parcial mayor a cero y menor al total adeudado."
        case .missingFinancialSessionType:
            return "Elegí un tipo facturable antes de completar la sesión."
        case .missingPatientCurrency:
            return "Configurá la moneda predeterminada del paciente antes de completar la sesión."
        case .missingResolvedPrice:
            return "Definí un honorario vigente para este tipo de sesión antes de completar."
        }
    }
}

@Observable
final class SessionViewModel {

    // MARK: - Campos editables del formulario

    var sessionDate: Date = Date().roundedToMinuteInterval(5) {
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
    var financialSessionTypeID: UUID? = nil
    var isCourtesy: Bool = false

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
        financialSessionTypeID = session.financialSessionType?.id
        isCourtesy = session.isCourtesy

        // Reconstruir DTOs desde los Diagnosis persistidos para que la UI
        // muestre los diagnósticos sin necesidad de llamar a la API.
        selectedDiagnoses = (session.diagnoses ?? []).map(\.asSearchResult)
    }

    // MARK: - Creación

    /// Crea una nueva Session vinculada al paciente y persiste los
    /// diagnósticos seleccionados como snapshots inmutables.
    /// Además sincroniza los diagnósticos vigentes del paciente.
    @MainActor
    func createSession(for patient: Patient, in context: ModelContext) throws -> Session {
        try validateDraftCompletionReadiness(for: patient, in: context)
        let selectedFinancialSessionType = try resolveSelectedFinancialSessionType(in: context)
        let session = Session(
            sessionDate: sessionDate,
            sessionType: sessionType,
            durationMinutes: durationMinutes,
            notes: notes.trimmed,
            chiefComplaint: chiefComplaint.trimmed,
            treatmentPlan: treatmentPlan.trimmed,
            status: status,
            patient: patient,
            financialSessionType: selectedFinancialSessionType,
            isCourtesy: isCourtesy
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

        syncCompletionMetadata(for: session)

        // Si la sesión nace ya completada, congelamos aquí el valor financiero
        // para que el historial quede estable desde su primera persistencia.
        freezeFinancialSnapshotIfNeeded(for: session, in: context)
        try context.save()
        return session
    }

    // MARK: - Actualización

    /// Actualiza una Session existente. Los diagnósticos se gestionan por
    /// diferencia: se eliminan los que ya no están y se crean los nuevos.
    /// Sincroniza diagnósticos vigentes del paciente si es la sesión más reciente.
    @MainActor
    func update(_ session: Session, in context: ModelContext) throws -> Session {
        if let patient = session.patient {
            try validateDraftCompletionReadiness(for: patient, in: context)
        }
        let selectedFinancialSessionType = try resolveSelectedFinancialSessionType(in: context)
        session.sessionDate = sessionDate
        session.sessionType = sessionType
        session.durationMinutes = durationMinutes
        session.notes = notes.trimmed
        session.chiefComplaint = chiefComplaint.trimmed
        session.treatmentPlan = treatmentPlan.trimmed
        session.status = status
        session.financialSessionType = selectedFinancialSessionType
        session.isCourtesy = isCourtesy
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

        syncCompletionMetadata(for: session)

        // Reaplicamos el congelamiento solo cuando la sesión terminó completada.
        // finalizeSessionPricing es idempotente y no pisa snapshots existentes.
        freezeFinancialSnapshotIfNeeded(for: session, in: context)
        try context.save()
        return session
    }

    // MARK: - Finalización clínica y pagos

    /// Prepara el resumen que necesita la sheet antes de cerrar la sesión.
    /// Esto desacopla la UI del detalle de los cálculos y deja un único
    /// origen para el importe y la moneda que se le mostrarán al usuario.
    @MainActor
    func preparePaymentFlow(for session: Session) -> CompletionDraft {
        let configurationIssue = completionConfigurationIssue(for: session)
        return CompletionDraft(
            sessionID: session.id,
            amountDue: session.effectivePrice,
            currencyCode: session.effectiveCurrency,
            isCourtesy: session.isCourtesy,
            configurationIssue: configurationIssue
        )
    }

    /// Calcula una vista previa del resultado financiero antes de guardar.
    /// La UI del formulario lo usa para mostrar moneda y honorario estimados
    /// sin necesitar crear una Session persistida ni repetir reglas contables.
    @MainActor
    func pricingPreview(for patient: Patient, in context: ModelContext) -> SessionPricingPreview {
        let selectedFinancialSessionType = try? resolveSelectedFinancialSessionType(in: context)
        let draftSession = Session(
            sessionDate: sessionDate,
            status: SessionStatusMapping.programada.rawValue,
            patient: patient,
            financialSessionType: selectedFinancialSessionType,
            isCourtesy: isCourtesy
        )

        return SessionPricingPreview(
            amount: draftSession.effectivePrice,
            currencyCode: draftSession.effectiveCurrency,
            isCourtesy: isCourtesy,
            configurationIssue: completionConfigurationIssue(for: draftSession)
        )
    }

    /// Completa la sesión y registra el cobro elegido por el usuario.
    /// Primero congela snapshots para que Payment copie moneda y total
    /// definitivos, y recién después persiste el movimiento contable.
    @MainActor
    func completeSession(
        _ session: Session,
        in context: ModelContext,
        paymentIntent: PaymentIntent
    ) throws {
        let wasCompleted = session.sessionStatusValue == .completada
        if wasCompleted, session.isCourtesy == false, (session.payments ?? []).isEmpty == false {
            throw SessionCompletionError.sessionAlreadyCompleted
        }

        if wasCompleted == false {
            try validateCompletionConfiguration(for: session)
            session.status = SessionStatusMapping.completada.rawValue
            session.updatedAt = Date()
        }

        syncCompletionMetadata(for: session)
        freezeFinancialSnapshotIfNeeded(for: session, in: context)
        try createPaymentIfNeeded(for: session, paymentIntent: paymentIntent, in: context)
        try context.save()
    }

    /// Centraliza los cambios de estado distintos al cierre con pago.
    /// El camino hacia "completada" debe pasar por completeSession para no
    /// saltear la captura de Payment ni duplicar decisiones financieras.
    @MainActor
    func applyStatusChange(
        _ newStatus: SessionStatusMapping,
        to session: Session,
        in context: ModelContext
    ) throws {
        guard newStatus != .completada else {
            throw SessionCompletionError.sessionAlreadyCompleted
        }

        session.status = newStatus.rawValue
        session.updatedAt = Date()
        syncCompletionMetadata(for: session)
        try context.save()
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

    /// Construye el servicio con el contexto activo de SwiftData para que
    /// la resolución de snapshots lea exactamente la misma transacción en memoria.
    @MainActor
    private func makePricingService(in context: ModelContext) -> SessionPricingService {
        SessionPricingService(modelContext: context)
    }

    /// Valida el estado del formulario antes de persistir una sesión completada.
    /// Así evitamos guardar registros ya cerrados con configuración financiera
    /// incompleta y luego obligar a la UI a remendar ese estado inconsistente.
    @MainActor
    private func validateDraftCompletionReadiness(
        for patient: Patient,
        in context: ModelContext
    ) throws {
        guard status == SessionStatusMapping.completada.rawValue else {
            return
        }

        if isCourtesy {
            return
        }

        guard let selectedFinancialSessionType = try resolveSelectedFinancialSessionType(in: context) else {
            throw SessionCompletionError.missingFinancialSessionType
        }

        let draftSession = Session(
            sessionDate: sessionDate,
            status: status,
            patient: patient,
            financialSessionType: selectedFinancialSessionType,
            isCourtesy: isCourtesy
        )

        switch completionConfigurationIssue(for: draftSession) {
        case .missingPatientCurrency:
            throw SessionCompletionError.missingPatientCurrency
        case .missingResolvedPrice:
            throw SessionCompletionError.missingResolvedPrice
        case .missingFinancialSessionType:
            throw SessionCompletionError.missingFinancialSessionType
        case nil:
            return
        }
    }

    /// Resuelve el tipo facturable elegido en el formulario.
    /// Se hace por UUID persistido para que la vista no transporte modelos
    /// vivos entre pantallas ni tenga que consultar SwiftData por su cuenta.
    @MainActor
    private func resolveSelectedFinancialSessionType(
        in context: ModelContext
    ) throws -> SessionCatalogType? {
        if isCourtesy {
            return nil
        }

        guard let financialSessionTypeID else {
            return nil
        }

        let descriptor = FetchDescriptor<SessionCatalogType>(
            predicate: #Predicate<SessionCatalogType> { sessionType in
                sessionType.id == financialSessionTypeID
            }
        )

        return try context.fetch(descriptor).first
    }

    /// Congela snapshots solo cuando la sesión está completada.
    /// Se llama desde crear, editar y completar para que cualquier entrada
    /// al cierre clínico use la misma regla financiera sin duplicación.
    @MainActor
    private func freezeFinancialSnapshotIfNeeded(for session: Session, in context: ModelContext) {
        guard session.sessionStatusValue == .completada else { return }
        makePricingService(in: context).finalizeSessionPricing(session: session)
    }

    /// Valida que la sesión tenga suficiente configuración para congelar
    /// snapshots coherentes. Evita persistir sesiones completadas con moneda
    /// vacía o precio cero cuando eso representa una configuración faltante.
    @MainActor
    private func validateCompletionConfiguration(for session: Session) throws {
        guard session.isCourtesy == false else {
            return
        }

        switch completionConfigurationIssue(for: session) {
        case .missingFinancialSessionType:
            throw SessionCompletionError.missingFinancialSessionType
        case .missingPatientCurrency:
            throw SessionCompletionError.missingPatientCurrency
        case .missingResolvedPrice:
            throw SessionCompletionError.missingResolvedPrice
        case nil:
            return
        }
    }

    /// Traduce el estado del modelo a una causa de bloqueo amigable para UI.
    /// Se reutiliza tanto en la validación como en el borrador del sheet para
    /// que el mensaje visual coincida exactamente con la regla persistente.
    @MainActor
    private func completionConfigurationIssue(
        for session: Session
    ) -> CompletionConfigurationIssue? {
        if session.isCourtesy {
            return nil
        }

        guard session.financialSessionType != nil else {
            return .missingFinancialSessionType
        }

        if session.effectiveCurrency.isEmpty {
            return .missingPatientCurrency
        }

        if session.effectivePrice <= 0 {
            return .missingResolvedPrice
        }

        return nil
    }

    /// Mantiene una fecha de completado estable para reporting financiero.
    /// Se setea solo al cerrar por primera vez y se limpia si la sesión vuelve
    /// a un estado abierto para evitar que el dashboard la siga contando.
    private func syncCompletionMetadata(for session: Session) {
        if session.sessionStatusValue == .completada {
            if session.completedAt == nil {
                session.completedAt = Date()
            }
        } else {
            session.completedAt = nil
        }
    }

    /// Crea Payment solo cuando la intención realmente representa un cobro.
    /// Las sesiones de cortesía y la opción "sin pago" no generan movimientos
    /// porque la deuda ya se deriva del precio final y la suma de pagos.
    @MainActor
    private func createPaymentIfNeeded(
        for session: Session,
        paymentIntent: PaymentIntent,
        in context: ModelContext
    ) throws {
        if session.isCourtesy {
            return
        }

        let finalPrice = session.finalPriceSnapshot ?? session.effectivePrice
        let paymentAmount: Decimal

        switch paymentIntent {
        case .full:
            guard finalPrice > 0 else { return }
            paymentAmount = finalPrice
        case .partial(let amount):
            guard amount > 0, amount < finalPrice else {
                throw SessionCompletionError.invalidPartialAmount
            }
            paymentAmount = amount
        case .none:
            return
        }

        let paymentCurrency = session.finalCurrencySnapshot ?? session.effectiveCurrency
        let payment = Payment(
            amount: paymentAmount,
            currencyCode: paymentCurrency,
            paidAt: Date(),
            session: session
        )
        context.insert(payment)
    }
}
