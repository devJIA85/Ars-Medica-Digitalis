//
//  SessionFormView.swift
//  Ars Medica Digitalis
//
//  Formulario para alta y edición de sesiones clínicas (HU-04).
//  Si recibe una Session existente, entra en modo edición.
//  Los diagnósticos CIE-11 se seleccionan desde ICD11SearchView.
//

import OSLog
import SwiftUI
import SwiftData

private struct PendingSessionCompletion: Identifiable {
    let patient: Patient
    let existingSessionID: UUID?
    let completionDraft: CompletionDraft
    let formSnapshot: SessionFormSnapshot

    var id: UUID { completionDraft.sessionID }
}

struct SessionFormView: View {

    private let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "CalendarSync")

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("calendar.didResolveInitialSuggestion.v1")
    private var didResolveInitialCalendarSuggestion = false

    let patient: Patient

    /// nil = modo alta, non-nil = modo edición
    let session: Session?

    /// Fecha inicial para sesiones nuevas creadas desde el calendario.
    /// Si es nil, el ViewModel usa Date() (ahora).
    let initialDate: Date?

    @State private var viewModel: SessionViewModel
    @State private var conflictingSessions: [Session] = []
    @State private var showingConflictAlert = false
    @State private var showAllDiagnoses = false
    @State private var persistenceErrorMessage: String?
    @State private var summaryGenerationErrorMessage: String?
    @State private var isGeneratingSummary = false
    @State private var isPersistingSession = false
    @State private var pendingCompletionFlow: PendingSessionCompletion?
    @State private var addToCalendar = false
    @State private var calendarAuthorizationState: CalendarAuthorizationState = .notDetermined
    @State private var calendarIntegrationService = CalendarIntegrationService()
    @State private var showingInitialCalendarSuggestion = false
    @State private var isCreatingSuggestedCalendar = false
    @State private var pricingPreview = SessionPricingPreview(
        amount: 0,
        currencyCode: "",
        isCourtesy: false,
        configurationIssue: .missingFinancialSessionType
    )
    private let summaryGenerator = SessionSummaryGenerator()

    /// Límite de diagnósticos visibles cuando la lista está colapsada.
    private static let diagnosisVisibleLimit = 3

    private var isEditing: Bool { session != nil }

    init(patient: Patient, session: Session? = nil, initialDate: Date? = nil) {
        self.patient = patient
        self.session = session
        self.initialDate = initialDate

        // Establecer la fecha inmediatamente en el init para evitar que
        // el DatePicker muestre "hoy" por un frame antes del onAppear.
        // En modo alta con fecha del calendario usamos una hora neutral
        // de consultorio, no la hora actual, para permitir cargar sesiones
        // pasadas del mismo día sin una fricción artificial.
        // En modo edición, load(from:) la sobreescribirá en onAppear.
        if let session {
            // Modo edición: load(from:) establece chiefComplaint en onAppear.
            _ = session
            _viewModel = State(initialValue: SessionViewModel())
        } else if let initialDate {
            // Modo alta con fecha del calendario.
            let resolved = initialDate.defaultSessionStartDate()
            let vm = SessionViewModel(initialDate: resolved)
            vm.applyDefaultChiefComplaint(for: patient)
            _viewModel = State(initialValue: vm)
        } else {
            // Modo alta sin fecha preseleccionada.
            let vm = SessionViewModel()
            vm.applyDefaultChiefComplaint(for: patient)
            _viewModel = State(initialValue: vm)
        }
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            // MARK: - Datos de la Sesión
            Section("Datos de la Sesión") {
                DatePicker(
                    "Fecha",
                    selection: sessionDateBinding,
                    displayedComponents: .date
                )

                // Hora con intervalos de 5 minutos (el DatePicker nativo
                // no soporta minuteInterval, así que usamos Pickers manuales)
                HStack {
                    Text("Hora")
                    Spacer()
                    Picker("", selection: selectedHourBinding) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Text(":")

                    Picker("", selection: selectedMinuteBinding) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Picker("Modalidad", selection: $viewModel.sessionType) {
                    ForEach(SessionViewModel.sessionTypes, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }

                Stepper(
                    "Duración: \(viewModel.durationMinutes) min",
                    value: $viewModel.durationMinutes,
                    in: 15...180,
                    step: 5
                )

                Picker("Estado", selection: $viewModel.status) {
                    ForEach(SessionViewModel.sessionStatuses, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }

                Toggle("Sesión de cortesía", isOn: $viewModel.isCourtesy)

                Toggle("Agregar al calendario", isOn: calendarSyncToggleBinding)

                if let calendarAccessMessage {
                    Text(calendarAccessMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isCourtesy == false {
                    if availableFinancialSessionTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tipo facturable")
                                .foregroundStyle(.primary)
                            Text(missingFinancialTypesMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Tipo facturable", selection: displayedFinancialSessionTypeBinding) {
                            if allowsEmptyFinancialSessionTypeSelection {
                                Text("Sin seleccionar").tag(nil as UUID?)
                            }
                            ForEach(availableFinancialSessionTypes) { sessionType in
                                Text(sessionType.name).tag(Optional(sessionType.id))
                            }
                        }
                    }
                }

                // Motivo de consulta integrado en la misma sección
                // para reducir cajas Liquid Glass
                TextField(
                    "Motivo de consulta",
                    text: $viewModel.chiefComplaint,
                    axis: .vertical
                )
                .lineLimit(2...4)
            }

            Section {
                if let configurationIssue = pricingPreview.configurationIssue {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Falta configuración financiera", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                            .symbolRenderingMode(.multicolor)
                            .symbolEffect(.wiggle, options: .nonRepeating)

                        Text(configurationIssue.message(resolvedCurrencyCode: pricingPreview.currencyCode))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                LabeledContent("Moneda del paciente", value: pricingPreviewCurrencyText)
                LabeledContent("Honorario estimado", value: pricingPreviewAmountText)

                if pricingPreview.isCourtesy {
                    HStack {
                        Text("Tipo")
                        Spacer()
                        Text("Cortesía")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                }
            } header: {
                Text("Resumen financiero")
            } footer: {
                Text("Este cálculo usa la fecha de la sesión, la moneda vigente del paciente y el honorario activo del tipo facturable.")
            }

            // MARK: - Diagnósticos CIE-11
            Section {
                // Filas visibles según estado colapsado/expandido
                ForEach(visibleDiagnoses) { diagnosis in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(diagnosis.title)
                                .font(.body)
                                .lineLimit(2)
                            if let code = diagnosis.theCode {
                                Text(code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button(role: .destructive) {
                            viewModel.removeDiagnosis(diagnosis)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Botón expandir/colapsar — solo visible cuando hay más del límite
                let hiddenCount = viewModel.selectedDiagnoses.count - Self.diagnosisVisibleLimit
                if hiddenCount > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllDiagnoses.toggle()
                        }
                    } label: {
                        Label(
                            showAllDiagnoses
                                ? "Mostrar menos"
                                : "Ver \(hiddenCount) diagnóstico\(hiddenCount == 1 ? "" : "s") más",
                            systemImage: showAllDiagnoses
                                ? "chevron.up"
                                : "chevron.down"
                        )
                        .font(.footnote)
                        .foregroundStyle(.tint)
                    }
                }

                NavigationLink {
                    ICD11SearchView(
                        alreadySelected: viewModel.selectedDiagnoses,
                        onSelect: { result in
                            viewModel.addDiagnosis(result)
                        }
                    )
                } label: {
                    Label("Agregar Diagnóstico", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }
            } header: {
                // Badge de conteo junto al título para visibilidad rápida
                HStack(spacing: 6) {
                    Text("Diagnósticos CIE-11")
                    if !viewModel.selectedDiagnoses.isEmpty {
                        Text("\(viewModel.selectedDiagnoses.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
            }

            // MARK: - Notas y Plan (unificados para layout compacto)
            Section("Notas y Plan") {
                // Cards editoriales estilo Notes/Health para lectura extensa
                // y edición con formato dentro del formulario clínico.
                RichTextClinicalEditor(
                    title: "Notas clínicas",
                    placeholder: "Notas clínicas: observaciones, evolución...",
                    text: $viewModel.notesRichText
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)

                RichTextClinicalEditor(
                    title: "Plan terapéutico",
                    placeholder: "Plan: indicaciones, derivaciones, próximos pasos...",
                    text: $viewModel.treatmentPlanRichText
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            Section("Resumen de sesión") {
                Button {
                    generateClinicalSummary()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if isGeneratingSummary {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(isGeneratingSummary ? "Generando resumen..." : "Generar resumen clínico")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(canGenerateClinicalSummary == false)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Resumen de sesión")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    ZStack(alignment: .topLeading) {
                        if viewModel.sessionSummary.trimmed.isEmpty {
                            Text("El resumen generado aparecerá aquí. Podés editarlo manualmente.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $viewModel.sessionSummary)
                            .font(.body)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                            .fill(Color(uiColor: .systemBackground))
                    )
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(isEditing ? "Editar Sesión" : "Nueva Sesión")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Guardar" : "Crear") {
                    save()
                }
                .disabled(!viewModel.canSave || isPersistingSession)
            }
        }
        .alert(
            "Conflicto de turno",
            isPresented: $showingConflictAlert
        ) {
            Button("Cancelar", role: .cancel) {}
            Button("Guardar igual") {
                saveIgnoringConflicts()
            }
        } message: {
            Text(conflictAlertMessage)
        }
        .alert("No se pudo guardar la sesión", isPresented: persistenceErrorBinding) {
            Button("Aceptar", role: .cancel) {
                persistenceErrorMessage = nil
            }
        } message: {
            Text(persistenceErrorMessage ?? "Ocurrió un error al persistir la sesión.")
        }
        .alert("No se pudo generar el resumen clínico", isPresented: summaryGenerationErrorBinding) {
            Button("Aceptar", role: .cancel) {
                summaryGenerationErrorMessage = nil
            }
        } message: {
            Text(summaryGenerationErrorMessage ?? "Ocurrió un error al generar el resumen.")
        }
        .sheet(item: $pendingCompletionFlow) { flow in
            PaymentFlowView(
                draft: flow.completionDraft,
                onCancel: {}
            ) { paymentIntent in
                try await persistPendingCompletion(flow, paymentIntent: paymentIntent)
                dismiss()
            }
        }
        .confirmationDialog(
            "Calendario para sesiones",
            isPresented: $showingInitialCalendarSuggestion,
            titleVisibility: .visible
        ) {
            Button("Crear \"\(suggestedCalendarName)\"") {
                Task { @MainActor in
                    await createSuggestedCalendarIfNeeded()
                }
            }
            .disabled(isCreatingSuggestedCalendar)

            Button("Usar calendario por defecto") {
                didResolveInitialCalendarSuggestion = true
            }

            Button("Ahora no", role: .cancel) {}
        } message: {
            Text("Podés crear un calendario dedicado para separar las sesiones clínicas del resto de tus eventos.")
        }
        .onAppear {
            if let session {
                viewModel.load(from: session)
                addToCalendar = session.calendarEventIdentifier?.isEmpty == false
            } else {
                // Pre-cargar diagnósticos vigentes del paciente
                // para que el profesional no tenga que re-seleccionarlos manualmente
                // en cada consulta de seguimiento.
                // La fecha ya fue configurada en el init de la vista.
                viewModel.preloadDiagnoses(from: patient)
                addToCalendar = false
            }
        }
        .task {
            await refreshCalendarAuthorizationState()
        }
        .task(id: pricingPreviewTaskID) {
            refreshPricingPreview()
        }
    }

    // MARK: - Helpers diagnósticos

    /// Diagnósticos visibles según estado expandido/colapsado.
    private var visibleDiagnoses: [ICD11SearchResult] {
        showAllDiagnoses
            ? viewModel.selectedDiagnoses
            : Array(viewModel.selectedDiagnoses.prefix(Self.diagnosisVisibleLimit))
    }

    /// Catálogo facturable activo del profesional del paciente.
    /// Se filtra por compatibilidad real con la moneda del paciente para no
    /// ofrecer tipos que luego fallen al resolver el honorario estimado.
    private var availableFinancialSessionTypes: [SessionCatalogType] {
        viewModel.availableFinancialSessionTypes(for: patient, in: modelContext)
    }

    /// Identificador estable para recalcular la vista previa cuando cambia
    /// cualquiera de los inputs que afectan moneda o precio estimados.
    private var pricingPreviewTaskID: String {
        [
            "\(viewModel.sessionDate.timeIntervalSinceReferenceDate)",
            viewModel.financialSessionTypeID?.uuidString ?? "none",
            viewModel.isCourtesy ? "courtesy" : "paid",
            patient.currencyCode,
        ].joined(separator: "|")
    }

    private var pricingPreviewCurrencyText: String {
        if pricingPreview.isCourtesy, pricingPreview.currencyCode.isEmpty {
            return "No aplica"
        }

        return pricingPreview.currencyCode.isEmpty ? "Sin configurar" : pricingPreview.currencyCode
    }

    private var pricingPreviewAmountText: String {
        if pricingPreview.isCourtesy {
            if pricingPreview.currencyCode.isEmpty {
                return "0"
            }

            return pricingPreview.amount.formattedCurrency(code: pricingPreview.currencyCode)
        }

        guard pricingPreview.isResolved else {
            if pricingPreview.configurationIssue == .missingResolvedPrice,
               pricingPreview.currencyCode.isEmpty == false {
                return L10n.tr("session.pricing.unresolved_for_currency", pricingPreview.currencyCode)
            }

            return "Sin resolver"
        }

        if pricingPreview.currencyCode.isEmpty {
            return NSDecimalNumber(decimal: pricingPreview.amount).stringValue
        }

        return pricingPreview.amount.formattedCurrency(code: pricingPreview.currencyCode)
    }

    private var calendarSyncToggleBinding: Binding<Bool> {
        Binding(
            get: { addToCalendar },
            set: { isEnabled in
                addToCalendar = isEnabled
                guard isEnabled else { return }

                Task { @MainActor in
                    let hasAccess = await ensureCalendarWriteAccess()
                    if hasAccess == false, calendarAuthorizationState.isDisabled {
                        addToCalendar = false
                    } else if hasAccess {
                        await presentInitialCalendarSuggestionIfNeeded()
                    }
                }
            }
        )
    }

    private var calendarAccessMessage: String? {
        switch calendarAuthorizationState {
        case .denied, .restricted:
            return "Ars Medica Digitalis necesita permiso de Calendario para sincronizar sesiones. Podés habilitarlo desde Configuración > Privacidad y Seguridad > Calendarios."
        case .notDetermined:
            if addToCalendar {
                return "Al guardar la sesión te vamos a pedir permiso para crear y actualizar eventos en tu calendario."
            }
            return nil
        case .writeOnly, .fullAccess:
            return nil
        }
    }

    private var suggestedCalendarName: String {
        let professionalName = patient.professional?.fullName.trimmed ?? ""
        if professionalName.isEmpty == false {
            return "Consultorio – \(professionalName)"
        }

        return "Consultorio – Ars Medica"
    }

    private var sessionDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.sessionDate },
            set: { newDate in
                // Preservar hora/minuto actuales al cambiar solo la fecha
                let calendar = Calendar.current
                var comps = calendar.dateComponents([.year, .month, .day], from: newDate)
                let timeComps = calendar.dateComponents([.hour, .minute], from: viewModel.sessionDate)
                comps.hour = timeComps.hour
                comps.minute = timeComps.minute
                comps.second = 0
                viewModel.sessionDate = calendar.date(from: comps) ?? newDate
            }
        )
    }

    private var selectedHourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: viewModel.sessionDate) },
            set: { newHour in
                let calendar = Calendar.current
                var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: viewModel.sessionDate)
                comps.hour = newHour
                comps.second = 0
                viewModel.sessionDate = calendar.date(from: comps) ?? viewModel.sessionDate
            }
        )
    }

    private var selectedMinuteBinding: Binding<Int> {
        Binding(
            get: {
                let minute = Calendar.current.component(.minute, from: viewModel.sessionDate)
                return (minute / 5) * 5
            },
            set: { newMinute in
                let calendar = Calendar.current
                var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: viewModel.sessionDate)
                comps.minute = newMinute
                comps.second = 0
                viewModel.sessionDate = calendar.date(from: comps) ?? viewModel.sessionDate
            }
        )
    }

    /// La vista refleja el tipo sugerido sin escribirlo en cada frame.
    /// Solo se persiste una selección explícita del usuario, lo que evita
    /// loops de actualización y mantiene el picker realmente editable.
    private var displayedFinancialSessionTypeBinding: Binding<UUID?> {
        Binding(
            get: {
                viewModel.displayedFinancialSessionTypeID(for: patient)
            },
            set: { newValue in
                viewModel.financialSessionTypeID = newValue
            }
        )
    }

    /// "Sin seleccionar" solo tiene sentido cuando no existe sugerencia.
    /// Si el dominio ya resolvió un tipo por defecto, mostrar una opción vacía
    /// induce a error porque la sesión igualmente terminaría usando el sugerido.
    private var allowsEmptyFinancialSessionTypeSelection: Bool {
        viewModel.suggestedFinancialSessionTypeID(for: patient) == nil
    }

    private var missingFinancialTypesMessage: String {
        let currencyCode = pricingPreview.currencyCode.isEmpty ? patient.currencyCode.trimmed : pricingPreview.currencyCode

        if currencyCode.isEmpty == false {
            return "No hay honorarios vigentes en \(currencyCode) para este paciente. Cargalos en Perfil > Honorarios para esa moneda."
        }

        return "Primero creá un honorario en Perfil > Honorarios para poder cobrar esta sesión."
    }

    /// Regla UX: solo habilitar generación cuando hay notas clínicas.
    private var canGenerateClinicalSummary: Bool {
        viewModel.notes.trimmed.isEmpty == false && isGeneratingSummary == false
    }

    private var summaryGenerationErrorBinding: Binding<Bool> {
        Binding(
            get: { summaryGenerationErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    summaryGenerationErrorMessage = nil
                }
            }
        )
    }

    // MARK: - Acciones

    @MainActor
    private func generateClinicalSummary() {
        let notes = viewModel.notes
        let plan = viewModel.treatmentPlan

        isGeneratingSummary = true
        summaryGenerationErrorMessage = nil

        Task {
            do {
                // La inferencia corre localmente sobre Foundation Models.
                let generatedSummary = try await summaryGenerator.generateSummary(
                    clinicalNotes: notes,
                    treatmentPlan: plan
                )

                await MainActor.run {
                    viewModel.sessionSummary = generatedSummary
                    isGeneratingSummary = false
                }
            } catch {
                await MainActor.run {
                    summaryGenerationErrorMessage = error.localizedDescription
                    isGeneratingSummary = false
                }
            }
        }
    }

    @MainActor
    private func save() {
        let conflicts = conflictingSessionsForSelectedDate()
        if !conflicts.isEmpty {
            conflictingSessions = conflicts
            showingConflictAlert = true
            return
        }

        saveIgnoringConflicts()
    }

    @MainActor
    private func saveIgnoringConflicts() {
        if requiresCompletionFlow {
            let snapshot = viewModel.buildFormSnapshot()
            pendingCompletionFlow = PendingSessionCompletion(
                patient: patient,
                existingSessionID: session?.id,
                completionDraft: viewModel.completionDraft(
                    for: snapshot,
                    patient: patient,
                    in: modelContext,
                    existingSessionID: session?.id
                ),
                formSnapshot: snapshot
            )
            return
        }

        guard isPersistingSession == false else {
            return
        }

        isPersistingSession = true
        let snapshot = viewModel.buildFormSnapshot()

        Task { @MainActor in
            defer {
                isPersistingSession = false
            }

            do {
                let persistedSession = try persistSession(using: snapshot)
                await synchronizeSessionCalendar(for: persistedSession)
                dismiss()
            } catch {
                persistenceErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func persistSession(using snapshot: SessionFormSnapshot) throws -> Session {
        if let session {
            return try viewModel.update(session, from: snapshot, in: modelContext)
        } else {
            return try viewModel.createSession(from: snapshot, for: patient, in: modelContext)
        }
    }

    /// Si el formulario deja la sesión como completada por primera vez,
    /// abrimos el mismo flujo de pago que usa el detalle para no saltear
    /// la captura de Payment ni duplicar UI contable.
    private var requiresCompletionFlow: Bool {
        let targetIsCompleted = viewModel.status == SessionStatusMapping.completada.rawValue
        let wasAlreadyCompleted = session?.sessionStatusValue == .completada
        return targetIsCompleted && wasAlreadyCompleted == false
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { persistenceErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    persistenceErrorMessage = nil
                }
            }
        )
    }

    private func conflictingSessionsForSelectedDate() -> [Session] {
        // Si la sesión actual queda cancelada, no se valida conflicto de agenda.
        guard viewModel.status != SessionStatusMapping.cancelada.rawValue else { return [] }

        let start = viewModel.sessionDate.startOfMinuteDate()
        let end = start.addingTimeInterval(60)
        let cancelledStatus = SessionStatusMapping.cancelada.rawValue
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { existing in
                existing.sessionDate >= start
                && existing.sessionDate < end
                && existing.status != cancelledStatus
            },
            sortBy: [SortDescriptor(\Session.sessionDate)]
        )
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        let currentSessionID = session?.id

        return allSessions.filter { existing in
            if let currentSessionID, existing.id == currentSessionID {
                return false
            }

            // Mientras corre la reparación one-shot, ignoramos acá los
            // borradores fantasma ya conocidos para no bloquear la agenda.
            if SessionPhantomHeuristics.isPhantomCandidate(existing) {
                return false
            }

            return true
        }
    }

    private var conflictAlertMessage: String {
        let when = viewModel.sessionDate.formatted(date: .abbreviated, time: .shortened)
        guard let first = conflictingSessions.first else {
            return "Ya existe otro turno asignado en ese horario."
        }

        if conflictingSessions.count == 1 {
            let patientName = first.patient?.fullName ?? "otro paciente"
            return "Ya existe un turno para \(patientName) en \(when)."
        }

        return "Ya existen \(conflictingSessions.count) turnos asignados en \(when)."
    }

    @MainActor
    private func refreshPricingPreview() {
        pricingPreview = viewModel.pricingPreview(for: patient, in: modelContext)
    }

    @MainActor
    private func persistPendingCompletion(
        _ flow: PendingSessionCompletion,
        paymentIntent: PaymentIntent
    ) async throws {
        let persistedSession: Session
        if let existingSessionID = flow.existingSessionID {
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { existing in
                    existing.id == existingSessionID
                }
            )
            guard let existingSession = try modelContext.fetch(descriptor).first else {
                throw NSError(
                    domain: "SessionFormView",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "No se encontró la sesión a completar."]
                )
            }

            persistedSession = try viewModel.updateAndCompleteSession(
                existingSession,
                from: flow.formSnapshot,
                in: modelContext,
                paymentIntent: paymentIntent
            )
        } else {
            persistedSession = try viewModel.createAndCompleteSession(
                from: flow.formSnapshot,
                for: flow.patient,
                in: modelContext,
                paymentIntent: paymentIntent
            )
        }

        await synchronizeSessionCalendar(for: persistedSession)
    }

    @MainActor
    private func refreshCalendarAuthorizationState() async {
        calendarAuthorizationState = await calendarIntegrationService.authorizationStatus()
    }

    @MainActor
    private func presentInitialCalendarSuggestionIfNeeded() async {
        guard didResolveInitialCalendarSuggestion == false else {
            return
        }

        let preferredCalendarIdentifier = await calendarIntegrationService.preferredCalendarIdentifier()
        if let preferredCalendarIdentifier, preferredCalendarIdentifier.isEmpty == false {
            didResolveInitialCalendarSuggestion = true
            return
        }

        showingInitialCalendarSuggestion = true
    }

    @MainActor
    private func createSuggestedCalendarIfNeeded() async {
        guard isCreatingSuggestedCalendar == false else {
            return
        }

        isCreatingSuggestedCalendar = true
        defer {
            isCreatingSuggestedCalendar = false
        }

        do {
            _ = try await calendarIntegrationService.createSuggestedCalendar(named: suggestedCalendarName)
            didResolveInitialCalendarSuggestion = true
        } catch {
            persistenceErrorMessage = "No se pudo crear el calendario sugerido. Podés seguir usando el calendario por defecto."
        }
    }

    @MainActor
    private func ensureCalendarWriteAccess() async -> Bool {
        let currentStatus = await calendarIntegrationService.authorizationStatus()
        calendarAuthorizationState = currentStatus

        switch currentStatus {
        case .fullAccess, .writeOnly:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            let requestedStatus = await calendarIntegrationService.requestAccess()
            calendarAuthorizationState = requestedStatus
            if requestedStatus == .notDetermined {
                let refreshedStatus = await calendarIntegrationService.authorizationStatus()
                calendarAuthorizationState = refreshedStatus
                return refreshedStatus.canWriteEvents
            }

            return requestedStatus.canWriteEvents
        }
    }

    /// Mantiene en un único lugar la sincronización create/update/delete.
    /// Si falla, la sesión queda guardada igual y la app no bloquea al usuario.
    @MainActor
    private func synchronizeSessionCalendar(for session: Session) async {
        if addToCalendar == false {
            guard let existingIdentifier = session.calendarEventIdentifier,
                  existingIdentifier.isEmpty == false else {
                return
            }

            guard await ensureCalendarWriteAccess() else {
                return
            }

            do {
                try await calendarIntegrationService.deleteEvent(identifier: existingIdentifier)
                session.calendarEventIdentifier = nil
                session.updatedAt = Date()
                try modelContext.save()
            } catch {
                logger.error("CalendarIntegrationService delete failed: \(error.localizedDescription, privacy: .private)")
            }
            return
        }

        guard await ensureCalendarWriteAccess() else {
            if calendarAuthorizationState.isDisabled {
                addToCalendar = false
            }
            return
        }

        do {
            let eventIdentifier: String
            if let existingIdentifier = session.calendarEventIdentifier,
               existingIdentifier.isEmpty == false {
                eventIdentifier = try await calendarIntegrationService.updateEvent(for: session)
            } else {
                eventIdentifier = try await calendarIntegrationService.createEvent(for: session)
            }

            if session.calendarEventIdentifier != eventIdentifier {
                session.calendarEventIdentifier = eventIdentifier
                session.updatedAt = Date()
                try modelContext.save()
            }
        } catch {
            logger.error("CalendarIntegrationService sync failed: \(error.localizedDescription, privacy: .private)")
        }
    }

}

#Preview {
    NavigationStack {
        SessionFormView(
            patient: Patient(
                firstName: "Ana",
                lastName: "García"
            )
        )
    }
    .modelContainer(ModelContainer.preview)
}
