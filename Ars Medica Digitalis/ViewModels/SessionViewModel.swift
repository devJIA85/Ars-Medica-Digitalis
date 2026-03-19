//
//  SessionViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para alta y edición de sesiones clínicas (HU-04).
//  Gestiona los campos del formulario y la lista de diagnósticos
//  seleccionados desde la búsqueda CIE-11.
//

import Foundation
import OSLog
import SwiftData

private extension AttributedString {
    /// Normaliza la lectura plana del rich text para validaciones y compatibilidad.
    var plainText: String {
        String(characters)
    }
}

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
struct CompletionDraft: Identifiable, Sendable {
    let sessionID: UUID
    let amountDue: Decimal
    let currencyCode: String
    let isCourtesy: Bool
    let configurationIssue: CompletionConfigurationIssue?

    var id: UUID { sessionID }

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

/// Borrador financiero puro para cálculos previos a la persistencia.
/// Mantiene referencias a modelos SwiftData solo dentro del MainActor y evita
/// crear Session @Model temporales que luego puedan filtrarse al contexto.
struct SessionFinancialDraft {
    let scheduledAt: Date
    let patient: Patient?
    let financialSessionType: SessionCatalogType?
    let isCourtesy: Bool
    let isCompleted: Bool
}

/// Snapshot inmutable del formulario antes de guardar.
/// Se usa para que validación, sheet de cobro y persistencia trabajen con el
/// mismo estado, sin depender de cambios reactivos posteriores de la vista.
struct SessionFormSnapshot: Sendable {
    let sessionDate: Date
    let sessionType: String
    let durationMinutes: Int
    let chiefComplaint: String
    let notes: String
    let treatmentPlan: String
    let sessionSummary: String
    let notesRichText: AttributedString
    let treatmentPlanRichText: AttributedString
    let status: String
    let financialSessionTypeID: UUID?
    let isCourtesy: Bool
    let selectedDiagnoses: [ICD11SearchResult]

    /// Mantiene el init histórico (notes/treatmentPlan en plano) y agrega
    /// rich text opcional para no romper tests ni consumidores existentes.
    init(
        sessionDate: Date,
        sessionType: String,
        durationMinutes: Int,
        chiefComplaint: String,
        notes: String,
        treatmentPlan: String,
        sessionSummary: String = "",
        notesRichText: AttributedString? = nil,
        treatmentPlanRichText: AttributedString? = nil,
        status: String,
        financialSessionTypeID: UUID?,
        isCourtesy: Bool,
        selectedDiagnoses: [ICD11SearchResult]
    ) {
        self.sessionDate = sessionDate
        self.sessionType = sessionType
        self.durationMinutes = durationMinutes
        self.chiefComplaint = chiefComplaint
        self.notes = notes
        self.treatmentPlan = treatmentPlan
        self.sessionSummary = sessionSummary
        self.notesRichText = notesRichText ?? AttributedString(notes)
        self.treatmentPlanRichText = treatmentPlanRichText ?? AttributedString(treatmentPlan)
        self.status = status
        self.financialSessionTypeID = financialSessionTypeID
        self.isCourtesy = isCourtesy
        self.selectedDiagnoses = selectedDiagnoses
    }

    /// Cuando el guardado requiere sheet de cobro, persistimos primero como
    /// programada y cerramos recién tras confirmar la intención de pago.
    /// Así evitamos sesiones intermedias ya insertadas antes de tiempo.
    func snapshotForCompletionPersistence() -> SessionFormSnapshot {
        SessionFormSnapshot(
            sessionDate: sessionDate,
            sessionType: sessionType,
            durationMinutes: durationMinutes,
            chiefComplaint: chiefComplaint,
            notes: notes,
            treatmentPlan: treatmentPlan,
            sessionSummary: sessionSummary,
            notesRichText: notesRichText,
            treatmentPlanRichText: treatmentPlanRichText,
            status: SessionStatusMapping.programada.rawValue,
            financialSessionTypeID: financialSessionTypeID,
            isCourtesy: isCourtesy,
            selectedDiagnoses: selectedDiagnoses
        )
    }
}

/// Explica por qué una sesión todavía no puede cerrarse financieramente.
/// Se expone al sheet para evitar UI engañosa cuando falta configuración base.
enum CompletionConfigurationIssue: Sendable, Equatable {
    case missingFinancialSessionType
    case missingPatientCurrency
    case missingResolvedPrice

    /// Devuelve un mensaje concreto para la UI según el contexto resuelto.
    /// Cuando falta precio pero la moneda sí existe, nombrar la divisa evita
    /// el ambiguo "Sin resolver" y orienta al profesional a corregir honorarios.
    func message(resolvedCurrencyCode: String = "") -> String {
        switch self {
        case .missingFinancialSessionType:
            return "Elegí un tipo facturable en la sesión antes de completarla."
        case .missingPatientCurrency:
            return "Configurá la moneda predeterminada en Paciente > Editar > Finanzas antes de completar la sesión."
        case .missingResolvedPrice:
            if resolvedCurrencyCode.isEmpty == false {
                return "Definí un honorario vigente en \(resolvedCurrencyCode) en Perfil > Honorarios para este tipo de sesión antes de completar."
            }

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
    case missingResolvedPrice(String)

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
        case .missingResolvedPrice(let resolvedCurrencyCode):
            if resolvedCurrencyCode.isEmpty == false {
                return "Definí un honorario vigente en \(resolvedCurrencyCode) para este tipo de sesión antes de completar."
            }

            return "Definí un honorario vigente para este tipo de sesión antes de completar."
        }
    }
}

@Observable
final class SessionViewModel {

    private let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "SessionViewModel")

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
    /// Fuente de verdad para el editor enriquecido iOS 26.
    var notesRichText: AttributedString = AttributedString()
    /// Fuente de verdad para el editor enriquecido iOS 26.
    var treatmentPlanRichText: AttributedString = AttributedString()
    /// Campo editable para resumen clínico manual o generado por IA local.
    var sessionSummary: String = ""
    var status: String = SessionStatusMapping.completada.rawValue
    var financialSessionTypeID: UUID? = nil
    var isCourtesy: Bool = false

    /// Compatibilidad con tests y flujos legacy que siguen leyendo/escribiendo String.
    var notes: String {
        get { notesRichText.plainText }
        set { notesRichText = AttributedString(newValue) }
    }

    /// Compatibilidad con texto plano fuera del editor rich text.
    var treatmentPlan: String {
        get { treatmentPlanRichText.plainText }
        set { treatmentPlanRichText = AttributedString(newValue) }
    }

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
    /// Delega el ajuste de status en `adjustStatusForDate()` para no duplicar
    /// la lógica que ya vive en ese método.
    init(initialDate: Date) {
        self.sessionDate = initialDate
        adjustStatusForDate()
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

        let active = patient.activeDiagnoses
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
        notesRichText = session.notesRichText
        treatmentPlanRichText = session.treatmentPlanRichText
        sessionSummary = session.sessionSummary
        status = session.status
        financialSessionTypeID = session.financialSessionType?.id
        isCourtesy = session.isCourtesy

        // Reconstruir DTOs desde los Diagnosis persistidos para que la UI
        // muestre los diagnósticos sin necesidad de llamar a la API.
        selectedDiagnoses = session.diagnoses.map(\.asSearchResult)
    }

    // MARK: - Creación

    /// Congela el estado actual del formulario.
    /// Este snapshot permite validar y persistir una sola vez aunque la vista
    /// siga recalculando previews o el usuario abra una sheet intermedia.
    func buildFormSnapshot() -> SessionFormSnapshot {
        SessionFormSnapshot(
            sessionDate: sessionDate,
            sessionType: sessionType,
            durationMinutes: durationMinutes,
            chiefComplaint: chiefComplaint.trimmed,
            notes: notesRichText.plainText.trimmed,
            treatmentPlan: treatmentPlanRichText.plainText.trimmed,
            sessionSummary: sessionSummary.trimmed,
            notesRichText: notesRichText,
            treatmentPlanRichText: treatmentPlanRichText,
            status: status,
            financialSessionTypeID: financialSessionTypeID,
            isCourtesy: isCourtesy,
            selectedDiagnoses: selectedDiagnoses
        )
    }

    /// Construye el borrador financiero que usa la sheet de cobro sin crear
    /// todavía una Session persistida. Así la UI puede confirmar o cancelar
    /// el cierre sin que SwiftData inserte registros intermedios.
    @MainActor
    func completionDraft(
        for snapshot: SessionFormSnapshot,
        patient: Patient,
        in context: ModelContext,
        existingSessionID: UUID? = nil
    ) -> CompletionDraft {
        let selectedFinancialSessionType = try? resolveFinancialSessionType(
            for: patient,
            selectedFinancialSessionTypeID: snapshot.financialSessionTypeID,
            scheduledAt: snapshot.sessionDate,
            in: context
        )
        let draft = SessionFinancialDraft(
            scheduledAt: snapshot.sessionDate,
            patient: patient,
            financialSessionType: selectedFinancialSessionType,
            isCourtesy: snapshot.isCourtesy,
            isCompleted: snapshot.status == SessionStatusMapping.completada.rawValue
        )
        let pricingService = makePricingService(in: context)

        return CompletionDraft(
            sessionID: existingSessionID ?? UUID(),
            amountDue: pricingService.resolveDynamicPrice(for: draft),
            currencyCode: pricingService.resolveEffectiveCurrency(for: draft),
            isCourtesy: snapshot.isCourtesy,
            configurationIssue: completionConfigurationIssue(
                for: draft,
                pricingService: pricingService
            )
        )
    }

    /// Crea una nueva Session vinculada al paciente y persiste los
    /// diagnósticos seleccionados como snapshots inmutables.
    /// Además sincroniza los diagnósticos vigentes del paciente.
    @MainActor
    func createSession(for patient: Patient, in context: ModelContext) throws -> Session {
        try createSession(from: buildFormSnapshot(), for: patient, in: context)
    }

    /// Persiste una nueva sesión a partir de un snapshot estable del formulario.
    /// Centralizar este camino evita que la vista inserte datos antes de decidir
    /// si necesita abrir el flujo de cobro o confirmar conflictos.
    @MainActor
    func createSession(
        from snapshot: SessionFormSnapshot,
        for patient: Patient,
        in context: ModelContext
    ) throws -> Session {
        try validateDraftCompletionReadiness(
            for: patient,
            snapshot: snapshot,
            in: context
        )
        let selectedFinancialSessionType = try resolveFinancialSessionType(
            for: patient,
            selectedFinancialSessionTypeID: snapshot.financialSessionTypeID,
            scheduledAt: snapshot.sessionDate,
            in: context
        )
        let session = Session(
            sessionDate: snapshot.sessionDate,
            sessionType: snapshot.sessionType,
            durationMinutes: snapshot.durationMinutes,
            notes: snapshot.notes,
            notesRichText: snapshot.notesRichText,
            chiefComplaint: snapshot.chiefComplaint,
            treatmentPlan: snapshot.treatmentPlan,
            sessionSummary: snapshot.sessionSummary,
            treatmentPlanRichText: snapshot.treatmentPlanRichText,
            status: snapshot.status,
            patient: patient,
            financialSessionType: selectedFinancialSessionType,
            isCourtesy: snapshot.isCourtesy
        )
        context.insert(session)

        // Snapshot inmutable de cada diagnóstico CIE-11 seleccionado
        for result in snapshot.selectedDiagnoses {
            let diagnosis = Diagnosis(from: result, session: session)
            context.insert(diagnosis)
        }

        // Sincronizar diagnósticos vigentes del paciente con los de esta sesión.
        // Solo cuando hubo cambios explícitos en diagnósticos durante esta edición.
        if didModifyDiagnoses {
            syncActiveDiagnoses(
                for: patient,
                selectedDiagnoses: snapshot.selectedDiagnoses,
                in: context
            )
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
        try update(session, from: buildFormSnapshot(), in: context)
    }

    /// Actualiza una sesión existente desde un snapshot congelado del formulario.
    /// Esto garantiza que el camino de edición use exactamente los mismos datos
    /// que fueron validados antes de mostrar conflictos o cobro.
    @MainActor
    func update(
        _ session: Session,
        from snapshot: SessionFormSnapshot,
        in context: ModelContext
    ) throws -> Session {
        if let patient = session.patient {
            try validateDraftCompletionReadiness(
                for: patient,
                snapshot: snapshot,
                in: context
            )
        }
        let selectedFinancialSessionType: SessionCatalogType?
        if let patient = session.patient {
            selectedFinancialSessionType = try resolveFinancialSessionType(
                for: patient,
                selectedFinancialSessionTypeID: snapshot.financialSessionTypeID,
                scheduledAt: snapshot.sessionDate,
                in: context
            )
        } else {
            selectedFinancialSessionType = nil
        }
        session.sessionDate = snapshot.sessionDate
        session.sessionType = snapshot.sessionType
        session.durationMinutes = snapshot.durationMinutes
        session.notesRichText = snapshot.notesRichText
        session.chiefComplaint = snapshot.chiefComplaint
        session.treatmentPlanRichText = snapshot.treatmentPlanRichText
        session.sessionSummary = snapshot.sessionSummary
        session.status = snapshot.status
        session.financialSessionType = selectedFinancialSessionType
        session.isCourtesy = snapshot.isCourtesy
        session.updatedAt = Date()

        // Reconciliar diagnósticos: eliminar los que ya no están seleccionados
        let existingDiagnoses = session.diagnoses
        let selectedURIs = Set(snapshot.selectedDiagnoses.map(\.id))

        for existing in existingDiagnoses {
            if !selectedURIs.contains(existing.icdURI) {
                context.delete(existing)
            }
        }

        // Agregar diagnósticos nuevos
        let existingURIs = Set(existingDiagnoses.map(\.icdURI))
        for result in snapshot.selectedDiagnoses where !existingURIs.contains(result.id) {
            let diagnosis = Diagnosis(from: result, session: session)
            context.insert(diagnosis)
        }

        // Sincronizar vigentes si esta es la sesión más reciente completada
        if didModifyDiagnoses, let patient = session.patient {
            syncActiveDiagnoses(
                for: patient,
                selectedDiagnoses: snapshot.selectedDiagnoses,
                in: context
            )
        }

        syncCompletionMetadata(for: session)

        // Reaplicamos el congelamiento solo cuando la sesión terminó completada.
        // finalizeSessionPricing es idempotente y no pisa snapshots existentes.
        freezeFinancialSnapshotIfNeeded(for: session, in: context)
        try context.save()
        return session
    }

    /// Crea una sesión nueva y la completa en una sola transacción lógica.
    /// La sesión solo se inserta cuando el usuario ya confirmó el cobro.
    @MainActor
    func createAndCompleteSession(
        from snapshot: SessionFormSnapshot,
        for patient: Patient,
        in context: ModelContext,
        paymentIntent: PaymentIntent
    ) throws -> Session {
        let persistedSession = try createSession(
            from: snapshot.snapshotForCompletionPersistence(),
            for: patient,
            in: context
        )
        try completeSession(persistedSession, in: context, paymentIntent: paymentIntent)
        return persistedSession
    }

    /// Actualiza una sesión existente y luego la completa usando el mismo
    /// snapshot que vio el usuario en la sheet de cobro.
    @MainActor
    func updateAndCompleteSession(
        _ session: Session,
        from snapshot: SessionFormSnapshot,
        in context: ModelContext,
        paymentIntent: PaymentIntent
    ) throws -> Session {
        let updatedSession = try update(
            session,
            from: snapshot.snapshotForCompletionPersistence(),
            in: context
        )
        try completeSession(updatedSession, in: context, paymentIntent: paymentIntent)
        return updatedSession
    }

    /// Elimina una sesión y limpia su evento de calendario asociado.
    /// Se expone como API reutilizable para futuros flujos de borrado explícito.
    @MainActor
    func deleteSession(
        _ session: Session,
        in context: ModelContext,
        calendarService: CalendarIntegrationService? = nil
    ) async throws {
        let service = calendarService ?? CalendarIntegrationService()
        if session.calendarEventIdentifier?.isEmpty == false {
            do {
                try await service.deleteEvent(for: session)
            } catch {
                // Si el evento ya no existe en EventKit, no bloqueamos el borrado clínico.
                logger.error("SessionViewModel calendar cleanup failed: \(error.localizedDescription, privacy: .private)")
            }
        }

        context.delete(session)
        try context.save()
    }

    // MARK: - Finalización clínica y pagos

    /// Prepara el resumen que necesita la sheet antes de cerrar la sesión.
    /// Esto desacopla la UI del detalle de los cálculos y deja un único
    /// origen para el importe y la moneda que se le mostrarán al usuario.
    @MainActor
    func preparePaymentFlow(for session: Session) -> CompletionDraft {
        let draft = financialDraft(for: session)
        let pricingService = makePricingService(
            in: session.modelContext ?? session.patient?.modelContext
        )
        let configurationIssue = completionConfigurationIssue(for: draft, pricingService: pricingService)
        return CompletionDraft(
            sessionID: session.id,
            amountDue: pricingService.resolveDynamicPrice(for: draft),
            currencyCode: pricingService.resolveEffectiveCurrency(for: draft),
            isCourtesy: draft.isCourtesy,
            configurationIssue: configurationIssue
        )
    }

    /// Calcula una vista previa del resultado financiero antes de guardar.
    /// La UI del formulario lo usa para mostrar moneda y honorario estimados
    /// sin necesitar crear una Session persistida ni repetir reglas contables.
    @MainActor
    func pricingPreview(for patient: Patient, in context: ModelContext) -> SessionPricingPreview {
        pricingPreview(
            for: patient,
            in: context,
            overridingFinancialSessionTypeID: financialSessionTypeID
        )
    }

    /// Permite calcular previews para un tipo facturable explícito sin mutar
    /// la selección del formulario. Esto habilita filtrar el picker por
    /// moneda del paciente sin meter lógica financiera en la vista.
    @MainActor
    func pricingPreview(
        for patient: Patient,
        in context: ModelContext,
        overridingFinancialSessionTypeID: UUID?
    ) -> SessionPricingPreview {
        let selectedFinancialSessionType = try? resolveFinancialSessionType(
            for: patient,
            selectedFinancialSessionTypeID: overridingFinancialSessionTypeID,
            scheduledAt: sessionDate,
            in: context
        )
        let draft = SessionFinancialDraft(
            scheduledAt: sessionDate,
            patient: patient,
            financialSessionType: selectedFinancialSessionType,
            isCourtesy: isCourtesy,
            isCompleted: status == SessionStatusMapping.completada.rawValue
        )
        let pricingService = makePricingService(in: context)

        return SessionPricingPreview(
            amount: pricingService.resolveDynamicPrice(for: draft),
            currencyCode: pricingService.resolveEffectiveCurrency(for: draft),
            isCourtesy: isCourtesy,
            configurationIssue: completionConfigurationIssue(for: draft, pricingService: pricingService)
        )
    }

    /// Expone el tipo facturable sugerido para que la vista refleje la misma
    /// decisión que usa el dominio al persistir o validar la sesión.
    @MainActor
    func suggestedFinancialSessionTypeID(for patient: Patient) -> UUID? {
        resolveSuggestedFinancialSessionType(
            for: patient,
            scheduledAt: sessionDate
        )?.id
    }

    /// Expone el tipo que la UI debe mostrar como seleccionado.
    /// Si el usuario todavía no eligió uno manualmente, la vista refleja la
    /// sugerencia operativa para evitar un estado visual inconsistente.
    @MainActor
    func displayedFinancialSessionTypeID(for patient: Patient) -> UUID? {
        financialSessionTypeID ?? suggestedFinancialSessionTypeID(for: patient)
    }

    /// Devuelve solo tipos facturables compatibles con la moneda vigente del
    /// paciente para la fecha de la sesión. Así la UI evita mezclar monedas
    /// y no le muestra al profesional opciones que nunca podrán cobrarse.
    @MainActor
    func availableFinancialSessionTypes(
        for patient: Patient,
        in context: ModelContext
    ) -> [SessionCatalogType] {
        resolveCompatibleFinancialSessionTypes(
            for: patient,
            scheduledAt: sessionDate
        )
    }

    /// Expone el nombre del tipo facturable efectivo de una sesión existente.
    /// Si la sesión todavía no lo persistió pero el profesional tiene una
    /// sugerencia operativa válida, la UI refleja ese valor real.
    @MainActor
    func effectiveFinancialSessionTypeName(for session: Session) -> String? {
        resolvedFinancialSessionType(for: session)?.name
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
        if wasCompleted, session.isCourtesy == false, session.payments.isEmpty == false {
            throw SessionCompletionError.sessionAlreadyCompleted
        }

        if wasCompleted == false {
            applyImplicitFinancialSessionTypeIfNeeded(to: session)
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
    private func syncActiveDiagnoses(
        for patient: Patient,
        selectedDiagnoses: [ICD11SearchResult],
        in context: ModelContext
    ) {
        let currentActive = patient.activeDiagnoses
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

    /// Algunos flujos leen contexto desde modelos todavía no persistidos.
    /// Aceptar nil permite reutilizar el mismo servicio sobre drafts puros
    /// sin forzar inserciones auxiliares solo para obtener un ModelContext.
    @MainActor
    private func makePricingService(in context: ModelContext?) -> SessionPricingService {
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
        try validateDraftCompletionReadiness(
            for: patient,
            snapshot: buildFormSnapshot(),
            in: context
        )
    }

    /// Valida el cierre financiero usando un snapshot puro del formulario.
    /// De este modo la comprobación no crea sesiones temporales dentro del
    /// contexto solo para saber si el honorario y la moneda son válidos.
    @MainActor
    private func validateDraftCompletionReadiness(
        for patient: Patient,
        snapshot: SessionFormSnapshot,
        in context: ModelContext
    ) throws {
        if snapshot.status != SessionStatusMapping.completada.rawValue {
            return
        }

        if snapshot.isCourtesy {
            return
        }

        guard let selectedFinancialSessionType = try resolveFinancialSessionType(
            for: patient,
            selectedFinancialSessionTypeID: snapshot.financialSessionTypeID,
            scheduledAt: snapshot.sessionDate,
            in: context
        ) else {
            throw SessionCompletionError.missingFinancialSessionType
        }

        let draft = SessionFinancialDraft(
            scheduledAt: snapshot.sessionDate,
            patient: patient,
            financialSessionType: selectedFinancialSessionType,
            isCourtesy: snapshot.isCourtesy,
            isCompleted: snapshot.status == SessionStatusMapping.completada.rawValue
        )
        let pricingService = makePricingService(in: context)

        switch completionConfigurationIssue(for: draft, pricingService: pricingService) {
        case .missingPatientCurrency:
            throw SessionCompletionError.missingPatientCurrency
        case .missingResolvedPrice:
            throw SessionCompletionError.missingResolvedPrice(
                pricingService.resolveEffectiveCurrency(for: draft)
            )
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
        for patient: Patient,
        in context: ModelContext
    ) throws -> SessionCatalogType? {
        try resolveFinancialSessionType(
            for: patient,
            selectedFinancialSessionTypeID: financialSessionTypeID,
            scheduledAt: sessionDate,
            in: context
        )
    }

    /// Resuelve un tipo facturable explícito o, si falta, la sugerencia
    /// operativa compatible con la moneda vigente del paciente.
    @MainActor
    private func resolveFinancialSessionType(
        for patient: Patient,
        selectedFinancialSessionTypeID: UUID?,
        scheduledAt: Date,
        in context: ModelContext
    ) throws -> SessionCatalogType? {
        if isCourtesy {
            return nil
        }

        guard let selectedFinancialSessionTypeID else {
            return resolveSuggestedFinancialSessionType(
                for: patient,
                scheduledAt: scheduledAt
            )
        }

        let descriptor = FetchDescriptor<SessionCatalogType>(
            predicate: #Predicate<SessionCatalogType> { sessionType in
                sessionType.id == selectedFinancialSessionTypeID
            }
        )

        return try context.fetch(descriptor).first ?? resolveSuggestedFinancialSessionType(
            for: patient,
            scheduledAt: scheduledAt
        )
    }

    /// Resuelve el tipo facturable efectivo de una sesión ya persistida.
    /// Permite que el flujo de cobro reutilice el mismo fallback de sugerencia
    /// que usa el formulario cuando la sesión aún no guardó el tipo.
    @MainActor
    private func resolvedFinancialSessionType(for session: Session) -> SessionCatalogType? {
        if session.isCourtesy {
            return nil
        }

        if let storedSessionType = session.financialSessionType {
            return storedSessionType
        }

        guard let patient = session.patient else {
            return nil
        }

        return resolveSuggestedFinancialSessionType(
            for: patient,
            scheduledAt: session.sessionDate
        )
    }

    /// Reúne la sugerencia operativa del profesional y el fallback de tipo único
    /// en un único punto para que la UI y la persistencia siempre coincidan.
    @MainActor
    private func resolveSuggestedFinancialSessionType(
        for patient: Patient,
        scheduledAt: Date
    ) -> SessionCatalogType? {
        let compatibleTypes = resolveCompatibleFinancialSessionTypes(
            for: patient,
            scheduledAt: scheduledAt
        )

        if let preferredID = patient.professional?.defaultFinancialSessionTypeID,
           let preferredType = compatibleTypes.first(where: { $0.id == preferredID }) {
            return preferredType
        }

        guard compatibleTypes.count == 1 else {
            return nil
        }

        return compatibleTypes.first
    }

    /// Filtra tipos activos por compatibilidad real con la moneda vigente del
    /// paciente. Esto evita sugerir el default administrativo si no se puede
    /// cobrar en la divisa que aplica a la sesión concreta.
    @MainActor
    private func resolveCompatibleFinancialSessionTypes(
        for patient: Patient,
        scheduledAt: Date
    ) -> [SessionCatalogType] {
        let activeTypes = resolveActiveFinancialSessionTypes(for: patient)
        guard activeTypes.isEmpty == false else {
            return []
        }

        let context = patient.modelContext ?? patient.professional?.modelContext
        let pricingService = SessionPricingService(modelContext: context)
        let compatibleTypes = activeTypes.filter { sessionType in
            pricingService.canResolvePrice(
                for: patient,
                sessionType: sessionType,
                scheduledAt: scheduledAt
            )
        }

        // Solo devolvemos tipos realmente cobrables en la moneda vigente.
        // Mostrar opciones incompatibles reintroduce resets visuales y errores
        // de guardado porque la UI termina mezclando divisas sin querer.
        return compatibleTypes
    }

    /// Consulta el catálogo activo desde SwiftData para que las sugerencias
    /// no dependan de relaciones aún no cargadas en memoria en el formulario.
    @MainActor
    private func resolveActiveFinancialSessionTypes(for patient: Patient) -> [SessionCatalogType] {
        guard let professional = patient.professional else {
            return []
        }

        let fallbackTypes = professional.sessionCatalogTypes
            .filter(\.isActive)
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }

        guard let context = patient.modelContext ?? professional.modelContext else {
            return fallbackTypes
        }

        let professionalID = professional.id
        let descriptor = FetchDescriptor<SessionCatalogType>(
            predicate: #Predicate<SessionCatalogType> { sessionType in
                sessionType.professional?.id == professionalID
            },
            sortBy: [
                SortDescriptor(\SessionCatalogType.sortOrder),
                SortDescriptor(\SessionCatalogType.createdAt),
            ]
        )

        guard let fetchedTypes = try? context.fetch(descriptor) else {
            return fallbackTypes
        }

        return fetchedTypes
            .filter(\.isActive)
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    /// Materializa en la sesión el tipo sugerido solo cuando todavía falta
    /// persistirlo. Esto evita que el cierre financiero falle por leer nil
    /// aunque el dominio ya tenga una sugerencia válida para esa sesión.
    @MainActor
    private func applyImplicitFinancialSessionTypeIfNeeded(to session: Session) {
        guard session.financialSessionType == nil else { return }
        session.financialSessionType = resolvedFinancialSessionType(for: session)
    }

    /// Proyecta una sesión persistida a un borrador puro para cálculos
    /// financieros. Esto reemplaza los Session temporales que antes podían
    /// filtrarse al contexto de SwiftData durante los renders del formulario.
    @MainActor
    private func financialDraft(for session: Session) -> SessionFinancialDraft {
        SessionFinancialDraft(
            scheduledAt: session.scheduledAt,
            patient: session.patient,
            financialSessionType: resolvedFinancialSessionType(for: session),
            isCourtesy: session.isCourtesy,
            isCompleted: session.isCompleted
        )
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

        let draft = financialDraft(for: session)
        let pricingService = makePricingService(
            in: session.modelContext ?? session.patient?.modelContext
        )
        switch completionConfigurationIssue(
            for: draft,
            pricingService: pricingService
        ) {
        case .missingFinancialSessionType:
            throw SessionCompletionError.missingFinancialSessionType
        case .missingPatientCurrency:
            throw SessionCompletionError.missingPatientCurrency
        case .missingResolvedPrice:
            throw SessionCompletionError.missingResolvedPrice(
                pricingService.resolveEffectiveCurrency(for: draft)
            )
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
        let pricingService = makePricingService(
            in: session.modelContext ?? session.patient?.modelContext
        )
        return completionConfigurationIssue(
            for: financialDraft(for: session),
            pricingService: pricingService
        )
    }

    /// Centraliza la traducción del estado financiero de un borrador a una
    /// causa de bloqueo visible por la UI. Mantener esta regla fuera de la
    /// vista evita que preview, sheet y guardado discrepen entre sí.
    @MainActor
    private func completionConfigurationIssue(
        for draft: SessionFinancialDraft,
        pricingService: SessionPricingService
    ) -> CompletionConfigurationIssue? {
        if draft.isCourtesy {
            return nil
        }

        guard draft.financialSessionType != nil else {
            return .missingFinancialSessionType
        }

        if pricingService.resolveEffectiveCurrency(for: draft).isEmpty {
            return .missingPatientCurrency
        }

        if pricingService.resolveDynamicPrice(for: draft) <= 0 {
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
                session.completedAt = min(session.sessionDate, Date())
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
