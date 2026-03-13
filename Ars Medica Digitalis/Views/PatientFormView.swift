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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let professional: Professional

    /// nil = modo alta, non-nil = modo edición
    let patient: Patient?

    // @State preserva el VM entre re-renders del padre (sheets, etc.)
    // @Bindable no lo hacía → se recreaba vacío y se perdían datos.
    @State private var viewModel: PatientViewModel
    @State private var flowState = PatientCreationState()

    private var isEditing: Bool { patient != nil }

    /// Países frecuentes calculados a partir de los pacientes del profesional
    private var frequentCountryCodes: [String] {
        CountryCatalog.frequentCodes(from: professional.patients ?? [])
    }

    init(professional: Professional, patient: Patient? = nil) {
        self.professional = professional
        self.patient = patient

        let vm = PatientViewModel()
        if let patient {
            vm.load(from: patient)
        } else {
            // Sembramos la moneda default del profesional solo en altas nuevas
            // para no pisar configuraciones ya existentes del paciente.
            vm.applyCreationDefaults(from: professional)
        }
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        PatientCreationFlowView(
            viewModel: viewModel,
            flowState: flowState,
            frequentCountryCodes: frequentCountryCodes,
            isEditing: isEditing,
            onCancel: { dismiss() },
            onSave: save
        )
        .navigationTitle(isEditing ? "Editar Paciente" : "Nuevo Paciente")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            flowState.adaptPresentationModeIfNeeded(
                verticalSizeClass: verticalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )
        }
        .onChange(of: verticalSizeClass) {
            flowState.adaptPresentationModeIfNeeded(
                verticalSizeClass: verticalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )
        }
        .onChange(of: dynamicTypeSize) {
            flowState.adaptPresentationModeIfNeeded(
                verticalSizeClass: verticalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )
        }
    }

    // MARK: - Acciones

    private func save() {
        if let patient {
            viewModel.update(patient, in: modelContext)
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
    .modelContainer(ModelContainer.preview)
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
    .modelContainer(ModelContainer.preview)
}
