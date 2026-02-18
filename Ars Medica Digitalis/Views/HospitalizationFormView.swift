//
//  HospitalizationFormView.swift
//  Ars Medica Digitalis
//
//  Formulario para alta y edición de internaciones previas.
//  Form simple con @State directo (sin ViewModel) — solo 3 campos.
//  Modo dual: hospitalization == nil → alta, non-nil → edición.
//

import SwiftUI
import SwiftData

struct HospitalizationFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let patient: Patient

    /// nil = modo alta, non-nil = modo edición
    let hospitalization: Hospitalization?

    @State private var admissionDate: Date = Date()
    @State private var durationDescription: String = ""
    @State private var observations: String = ""

    private var isEditing: Bool { hospitalization != nil }

    init(patient: Patient, hospitalization: Hospitalization? = nil) {
        self.patient = patient
        self.hospitalization = hospitalization
    }

    var body: some View {
        Form {
            Section("Internación") {
                DatePicker(
                    "Fecha de ingreso",
                    selection: $admissionDate,
                    in: ...Date.now,
                    displayedComponents: .date
                )

                TextField("Duración (ej: 15 días, 3 semanas)", text: $durationDescription)

                TextField(
                    "Motivo y observaciones",
                    text: $observations,
                    axis: .vertical
                )
                .lineLimit(3...6)
            }
        }
        .navigationTitle(isEditing ? "Editar Internación" : "Nueva Internación")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Guardar" : "Crear") {
                    save()
                }
            }
        }
        .onAppear {
            if let hospitalization {
                admissionDate = hospitalization.admissionDate
                durationDescription = hospitalization.durationDescription
                observations = hospitalization.observations
            }
        }
    }

    private func save() {
        if let hospitalization {
            // Edición
            hospitalization.admissionDate = admissionDate
            hospitalization.durationDescription = durationDescription.trimmingCharacters(in: .whitespaces)
            hospitalization.observations = observations.trimmingCharacters(in: .whitespaces)
        } else {
            // Alta
            let newHospitalization = Hospitalization(
                admissionDate: admissionDate,
                durationDescription: durationDescription.trimmingCharacters(in: .whitespaces),
                observations: observations.trimmingCharacters(in: .whitespaces),
                patient: patient
            )
            modelContext.insert(newHospitalization)
        }
        dismiss()
    }
}
