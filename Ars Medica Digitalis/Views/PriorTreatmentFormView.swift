//
//  PriorTreatmentFormView.swift
//  Ars Medica Digitalis
//
//  Formulario para alta y edición de antecedentes de tratamientos previos.
//  Form simple con @State directo (sin ViewModel) ya que solo tiene 5 campos.
//  Modo dual: treatment == nil → alta, treatment != nil → edición.
//

import SwiftUI
import SwiftData

struct PriorTreatmentFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let patient: Patient

    /// nil = modo alta, non-nil = modo edición
    let treatment: PriorTreatment?

    @State private var treatmentType: String = ""
    @State private var durationDescription: String = ""
    @State private var medication: String = ""
    @State private var outcome: String = ""
    @State private var observations: String = ""

    private var isEditing: Bool { treatment != nil }

    // Opciones para pickers
    static let treatmentTypes: [(String, String)] = [
        ("psicoterapia", "Psicoterapia"),
        ("psiquiatría", "Psiquiatría"),
        ("otro", "Otro"),
    ]

    static let outcomeOptions: [(String, String)] = [
        ("", "Sin especificar"),
        ("alta", "Alta"),
        ("abandono", "Abandono"),
        ("derivación", "Derivación"),
        ("en curso", "En curso"),
        ("otro", "Otro"),
    ]

    init(patient: Patient, treatment: PriorTreatment? = nil) {
        self.patient = patient
        self.treatment = treatment
    }

    var body: some View {
        Form {
            Section("Tratamiento") {
                Picker("Tipo", selection: $treatmentType) {
                    ForEach(Self.treatmentTypes, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }

                TextField("Duración (ej: 2 años, 6 meses)", text: $durationDescription)

                TextField("Medicación utilizada", text: $medication)

                Picker("Resultado", selection: $outcome) {
                    ForEach(Self.outcomeOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }

                TextField(
                    "Observaciones",
                    text: $observations,
                    axis: .vertical
                )
                .lineLimit(2...5)
            }
        }
        .navigationTitle(isEditing ? "Editar Tratamiento" : "Nuevo Tratamiento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Guardar" : "Crear") {
                    save()
                }
                .disabled(treatmentType.isEmpty)
            }
        }
        .onAppear {
            if let treatment {
                treatmentType = treatment.treatmentType
                durationDescription = treatment.durationDescription
                medication = treatment.medication
                outcome = treatment.outcome
                observations = treatment.observations
            }
        }
    }

    private func save() {
        if let treatment {
            // Edición
            treatment.treatmentType = treatmentType
            treatment.durationDescription = durationDescription.trimmingCharacters(in: .whitespaces)
            treatment.medication = medication.trimmingCharacters(in: .whitespaces)
            treatment.outcome = outcome
            treatment.observations = observations.trimmingCharacters(in: .whitespaces)
        } else {
            // Alta
            let newTreatment = PriorTreatment(
                treatmentType: treatmentType,
                durationDescription: durationDescription.trimmingCharacters(in: .whitespaces),
                medication: medication.trimmingCharacters(in: .whitespaces),
                outcome: outcome,
                observations: observations.trimmingCharacters(in: .whitespaces),
                patient: patient
            )
            modelContext.insert(newTreatment)
        }
        dismiss()
    }
}
