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
    @State private var showAllDiagnoses = false

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

                // Motivo de consulta integrado en la misma sección
                // para reducir cajas Liquid Glass
                TextField(
                    "Motivo de consulta",
                    text: $viewModel.chiefComplaint,
                    axis: .vertical
                )
                .lineLimit(2...4)
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
                persistSession()
                dismiss()
            }
        } message: {
            Text(conflictAlertMessage)
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
    }

    // MARK: - Helpers diagnósticos

    /// Diagnósticos visibles según estado expandido/colapsado.
    private var visibleDiagnoses: [ICD11SearchResult] {
        showAllDiagnoses
            ? viewModel.selectedDiagnoses
            : Array(viewModel.selectedDiagnoses.prefix(Self.diagnosisVisibleLimit))
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

    private func save() {
        let conflicts = conflictingSessionsForSelectedDate()
        if !conflicts.isEmpty {
            conflictingSessions = conflicts
            showingConflictAlert = true
            return
        }

        persistSession()
        dismiss()
    }

    private func persistSession() {
        if let session {
            viewModel.update(session, in: modelContext)
        } else {
            viewModel.createSession(for: patient, in: modelContext)
        }
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
