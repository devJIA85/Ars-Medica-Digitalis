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

    @Bindable var viewModel = SessionViewModel()

    private var isEditing: Bool { session != nil }

    init(patient: Patient, session: Session? = nil) {
        self.patient = patient
        self.session = session
    }

    var body: some View {
        Form {
            // MARK: - Datos de la Sesión
            Section("Datos de la Sesión") {
                DatePicker(
                    "Fecha",
                    selection: $viewModel.sessionDate,
                    in: ...Date.now,
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
            }

            // MARK: - Motivo de Consulta
            Section("Motivo de Consulta") {
                TextField(
                    "Motivo principal de la consulta",
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

            // MARK: - Notas Clínicas
            Section("Notas Clínicas") {
                TextField(
                    "Observaciones, evolución, hallazgos...",
                    text: $viewModel.notes,
                    axis: .vertical
                )
                .lineLimit(4...10)
            }

            // MARK: - Plan de Tratamiento
            Section("Plan de Tratamiento") {
                TextField(
                    "Indicaciones, derivaciones, próximos pasos...",
                    text: $viewModel.treatmentPlan,
                    axis: .vertical
                )
                .lineLimit(3...8)
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
                // Modo alta: pre-cargar diagnósticos de la última sesión completada
                // para que el profesional no tenga que re-seleccionarlos manualmente
                // en cada consulta de seguimiento.
                viewModel.preloadDiagnoses(from: patient)
            }
        }
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
        for: [Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self],
        inMemory: true
    )
}
