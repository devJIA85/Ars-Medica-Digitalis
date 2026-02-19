//
//  PatientFormView.swift
//  Ars Medica Digitalis
//
//  Formulario para alta (HU-02) y edición (HU-03) de pacientes.
//  Se enfoca en datos demográficos, identificación y contacto.
//  La historia clínica se gestiona desde PatientMedicalHistoryView.
//

import SwiftUI
import SwiftData

struct PatientFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let professional: Professional

    /// nil = modo alta, non-nil = modo edición
    let patient: Patient?

    @Bindable var viewModel = PatientViewModel()

    private var isEditing: Bool { patient != nil }

    init(professional: Professional, patient: Patient? = nil) {
        self.professional = professional
        self.patient = patient
    }

    var body: some View {
        Form {
            // MARK: - Foto y Datos Personales
            Section("Foto y Datos Personales") {
                ProfilePhotoPickerView(
                    photoData: $viewModel.photoData,
                    genderHint: viewModel.gender.isEmpty
                        ? viewModel.biologicalSex
                        : viewModel.gender,
                    onResize: { viewModel.resizePhoto($0) }
                )

                TextField("Nombre", text: $viewModel.firstName)
                    .textContentType(.givenName)

                TextField("Apellido", text: $viewModel.lastName)
                    .textContentType(.familyName)

                DatePicker(
                    "Fecha de Nacimiento",
                    selection: $viewModel.dateOfBirth,
                    in: ...Date.now,
                    displayedComponents: .date
                )

                Picker("Sexo Biológico", selection: $viewModel.biologicalSex) {
                    Text("No especificado").tag("")
                    Text("Masculino").tag("masculino")
                    Text("Femenino").tag("femenino")
                    Text("Intersexual").tag("intersexual")
                }

                Picker("Género", selection: $viewModel.gender) {
                    ForEach(PatientViewModel.genderOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }

                Picker("Estado Civil", selection: $viewModel.maritalStatus) {
                    ForEach(PatientViewModel.maritalStatusOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }

                TextField("Nacionalidad", text: $viewModel.nationality)

                TextField("País de Residencia", text: $viewModel.residenceCountry)

                TextField("Ocupación", text: $viewModel.occupation)

                Picker("Nivel Académico", selection: $viewModel.educationLevel) {
                    ForEach(PatientViewModel.educationLevelOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
            }

            // MARK: - Identificación y Cobertura
            Section("Identificación y Cobertura") {
                TextField("Documento de Identidad", text: $viewModel.nationalId)
                    .textContentType(.none)
                    .keyboardType(.numberPad)

                TextField("Obra Social", text: $viewModel.healthInsurance)

                TextField("Nº de Afiliado", text: $viewModel.insuranceMemberNumber)
                    .keyboardType(.numberPad)

                TextField("Plan", text: $viewModel.insurancePlan)
            }

            // MARK: - Contacto
            Section("Contacto") {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                TextField("Teléfono", text: $viewModel.phoneNumber)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)

                TextField("Dirección", text: $viewModel.address)
                    .textContentType(.fullStreetAddress)

                // Contacto de emergencia
                TextField("Emergencia: Nombre", text: $viewModel.emergencyContactName)

                TextField("Emergencia: Teléfono", text: $viewModel.emergencyContactPhone)
                    .keyboardType(.phonePad)

                Picker("Emergencia: Vínculo", selection: $viewModel.emergencyContactRelation) {
                    ForEach(PatientViewModel.emergencyRelationOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Editar Paciente" : "Nuevo Paciente")
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
            if let patient {
                viewModel.load(from: patient)
            }
        }
    }

    // MARK: - Acciones

    private func save() {
        if let patient {
            viewModel.update(patient)
        } else {
            viewModel.createPatient(for: professional, in: modelContext)
        }
        dismiss()
    }
}

#Preview("Alta") {
    NavigationStack {
        PatientFormView(
            professional: Professional(
                fullName: "Dr. Test",
                licenseNumber: "MN 999",
                specialty: "Psicología"
            )
        )
    }
    .modelContainer(for: [Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self, PriorTreatment.self, Hospitalization.self, AnthropometricRecord.self], inMemory: true)
}

#Preview("Edición") {
    NavigationStack {
        PatientFormView(
            professional: Professional(
                fullName: "Dr. Test",
                licenseNumber: "MN 999",
                specialty: "Psicología"
            ),
            patient: Patient(
                firstName: "Ana",
                lastName: "García",
                email: "ana@example.com"
            )
        )
    }
    .modelContainer(for: [Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self, PriorTreatment.self, Hospitalization.self, AnthropometricRecord.self], inMemory: true)
}
