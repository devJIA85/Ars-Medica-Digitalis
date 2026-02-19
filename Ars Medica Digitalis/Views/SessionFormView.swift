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

    @Bindable var viewModel = SessionViewModel()

    private var isEditing: Bool { session != nil }

    init(patient: Patient, session: Session? = nil, initialDate: Date? = nil) {
        self.patient = patient
        self.session = session
        self.initialDate = initialDate
    }

    var body: some View {
        Form {
            // MARK: - Datos de la Sesión
            Section("Datos de la Sesión") {
                DatePicker(
                    "Fecha",
                    selection: sessionDateBinding,
                    displayedComponents: [.date, .hourAndMinute]
                )

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
            Section("Diagnósticos CIE-11") {
                ForEach(viewModel.selectedDiagnoses) { diagnosis in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(diagnosis.title)
                                .font(.body)
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
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Guardar" : "Crear") {
                    save()
                }
                .disabled(!viewModel.canSave)
            }
        }
        .onAppear {
            if let session {
                viewModel.load(from: session)
            } else {
                // Fecha preseleccionada desde el calendario (si existe)
                if let initialDate {
                    viewModel.sessionDate = initialDate.roundedToMinuteInterval(5)
                } else {
                    viewModel.sessionDate = viewModel.sessionDate.roundedToMinuteInterval(5)
                }
                // Pre-cargar diagnósticos vigentes del paciente
                // para que el profesional no tenga que re-seleccionarlos manualmente
                // en cada consulta de seguimiento.
                viewModel.preloadDiagnoses(from: patient)
            }
        }
    }

    private var sessionDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.sessionDate },
            set: { newDate in
                viewModel.sessionDate = newDate.roundedToMinuteInterval(5)
            }
        )
    }

    // MARK: - Acciones

    private func save() {
        if let session {
            viewModel.update(session, in: modelContext)
        } else {
            viewModel.createSession(for: patient, in: modelContext)
        }
        dismiss()
    }
}

private extension Date {
    func roundedToMinuteInterval(_ interval: Int, calendar: Calendar = .current) -> Date {
        guard interval > 0 else { return self }
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        guard let minute = components.minute else { return self }

        let rounded = Int((Double(minute) / Double(interval)).rounded()) * interval
        if rounded >= 60 {
            components.minute = 0
            if let hour = components.hour {
                components.hour = hour + 1
            }
        } else {
            components.minute = rounded
        }
        components.second = 0

        return calendar.date(from: components) ?? self
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
    .modelContainer(
        for: [Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self, PriorTreatment.self, Hospitalization.self],
        inMemory: true
    )
}
