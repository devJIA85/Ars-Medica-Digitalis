//
//  SessionFormView.swift
//  Ars Medica Digitalis
//
//  Formulario para alta y edición de sesiones clínicas (HU-04).
//  Si recibe una Session existente, entra en modo edición.
//  Los diagnósticos CIE-11 se seleccionan desde ICD11SearchView.
//

import SwiftUI
import SwiftData

struct SessionFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let patient: Patient

    /// nil = modo alta, non-nil = modo edición
    let session: Session?

    /// Fecha inicial para sesiones nuevas creadas desde el calendario.
    /// Si es nil, el ViewModel usa Date() (ahora).
    let initialDate: Date?

    @Bindable var viewModel: SessionViewModel
    @State private var conflictingSessions: [Session] = []
    @State private var showingConflictAlert = false
    @State private var showingPaymentFlow = false
    @State private var showAllDiagnoses = false
    @State private var persistenceErrorMessage: String?
    @State private var completionDraft: CompletionDraft?
    @State private var pendingCompletionSession: Session?
    @State private var pricingPreview = SessionPricingPreview(
        amount: 0,
        currencyCode: "",
        isCourtesy: false,
        configurationIssue: .missingFinancialSessionType
    )

    /// Límite de diagnósticos visibles cuando la lista está colapsada.
    private static let diagnosisVisibleLimit = 3

    private var isEditing: Bool { session != nil }

    init(patient: Patient, session: Session? = nil, initialDate: Date? = nil) {
        self.patient = patient
        self.session = session
        self.initialDate = initialDate

        // Establecer la fecha inmediatamente en el init para evitar que
        // el DatePicker muestre "hoy" por un frame antes del onAppear.
        // En modo alta con fecha del calendario: día seleccionado + hora actual.
        // En modo edición, load(from:) la sobreescribirá en onAppear.
        if session == nil, let initialDate {
            let resolved = initialDate
                .combiningTimeFrom(Date())
                .roundedToMinuteInterval(5)
            self.viewModel = SessionViewModel(initialDate: resolved)
        } else {
            self.viewModel = SessionViewModel()
        }
    }

    var body: some View {
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

                if viewModel.isCourtesy == false {
                    if availableFinancialSessionTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tipo facturable")
                                .foregroundStyle(.primary)
                            Text("Primero creá un honorario en Perfil > Honorarios para poder cobrar esta sesión.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Tipo facturable", selection: $viewModel.financialSessionTypeID) {
                            Text("Sin seleccionar").tag(nil as UUID?)
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

                        Text(configurationIssue.message)
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
                TextField(
                    "Notas clínicas: observaciones, evolución...",
                    text: $viewModel.notes,
                    axis: .vertical
                )
                .lineLimit(3...8)

                TextField(
                    "Plan: indicaciones, derivaciones, próximos pasos...",
                    text: $viewModel.treatmentPlan,
                    axis: .vertical
                )
                .lineLimit(2...6)
            }
        }
        .navigationTitle(isEditing ? "Editar Sesión" : "Nueva Sesión")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Guardar" : "Crear") {
                    save()
                }
                .disabled(!viewModel.canSave)
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
        .sheet(isPresented: $showingPaymentFlow) {
            if let completionDraft, let pendingCompletionSession {
                PaymentFlowView(draft: completionDraft) { paymentIntent in
                    try viewModel.completeSession(
                        pendingCompletionSession,
                        in: modelContext,
                        paymentIntent: paymentIntent
                    )
                    dismiss()
                }
            }
        }
        .onAppear {
            if let session {
                viewModel.load(from: session)
            } else {
                // Pre-cargar diagnósticos vigentes del paciente
                // para que el profesional no tenga que re-seleccionarlos manualmente
                // en cada consulta de seguimiento.
                // La fecha ya fue configurada en el init de la vista.
                viewModel.preloadDiagnoses(from: patient)
            }
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
    /// Se usa directo desde la relación ya cargada para no duplicar queries
    /// en la vista cuando solo necesitamos poblar un picker simple.
    private var availableFinancialSessionTypes: [SessionCatalogType] {
        ((patient.professional?.sessionCatalogTypes) ?? [])
            .filter(\.isActive)
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
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
            return "Sin resolver"
        }

        if pricingPreview.currencyCode.isEmpty {
            return NSDecimalNumber(decimal: pricingPreview.amount).stringValue
        }

        return pricingPreview.amount.formattedCurrency(code: pricingPreview.currencyCode)
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

    // MARK: - Acciones

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
        do {
            let savedSession = try persistSession()
            if requiresCompletionFlow {
                prepareCompletionFlow(for: savedSession)
            } else {
                dismiss()
            }
        } catch {
            persistenceErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func persistSession() throws -> Session {
        if let session {
            return try viewModel.update(session, in: modelContext)
        } else {
            return try viewModel.createSession(for: patient, in: modelContext)
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

    @MainActor
    private func prepareCompletionFlow(for session: Session) {
        pendingCompletionSession = session
        completionDraft = viewModel.preparePaymentFlow(for: session)
        showingPaymentFlow = true
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

        let descriptor = FetchDescriptor<Session>()
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        let currentSessionID = session?.id

        return allSessions.filter { existing in
            if let currentSessionID, existing.id == currentSessionID {
                return false
            }
            guard existing.status != SessionStatusMapping.cancelada.rawValue else {
                return false
            }
            return Calendar.current.isDate(existing.sessionDate, equalTo: viewModel.sessionDate, toGranularity: .minute)
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
