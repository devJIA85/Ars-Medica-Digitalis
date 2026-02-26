//
//  PatientMedicalHistoryFormView.swift
//  Ars Medica Digitalis
//
//  Formulario editable para los campos escalares de historia clínica:
//  medicación actual, antropometría, estilo de vida y antecedentes familiares.
//  Siempre opera en modo edición (el paciente ya existe).
//  Usa PatientViewModel para load/update.
//

import SwiftUI
import SwiftData

struct PatientMedicalHistoryFormView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let patient: Patient

    // @State preserva el VM entre re-renders (al cerrar sheets de medicamentos).
    @State private var viewModel: PatientViewModel

    @State private var selectedMedications: [Medication] = []
    @State private var initialSelectedMedicationIDs: Set<UUID> = []
    @State private var didTouchMedicationSelection: Bool = false
    @State private var showingMedicationPicker: Bool = false
    @State private var infoMedication: Medication? = nil

    init(patient: Patient) {
        self.patient = patient
        let vm = PatientViewModel()
        vm.load(from: patient)
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        Form {
            // MARK: - Medicación Actual
            Section("Medicación Actual") {
                if selectedMedications.isEmpty {
                    Text("Sin medicación registrada")
                        .foregroundStyle(.secondary)

                    if !viewModel.currentMedication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        LabeledContent("Texto previo") {
                            Text(viewModel.currentMedication)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } else {
                    ForEach(sortedSelectedMedications) { medication in
                        SelectedMedicationRow(
                            medication: medication,
                            onRemove: {
                                removeMedication(medication)
                            },
                            onInfo: {
                                infoMedication = medication
                            }
                        )
                    }
                }

                Button {
                    showingMedicationPicker = true
                } label: {
                    Label("Agregar medicamentos", systemImage: "plus.circle")
                }
            }

            // MARK: - Antropometría
            Section("Antropometría") {
                HStack {
                    Text("Peso (kg)")
                    Spacer()
                    TextField("0", value: $viewModel.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Altura (cm)")
                    Spacer()
                    TextField("0", value: $viewModel.heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Cintura (cm)")
                    Spacer()
                    TextField("0", value: $viewModel.waistCm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                // IMC calculado automáticamente
                if let bmi = viewModel.bmi {
                    LabeledContent("IMC") {
                        Text(String(format: "%.1f - %@", bmi, viewModel.bmiCategory))
                            .foregroundStyle(bmiColor)
                    }
                }
            }

            // MARK: - Estilo de Vida
            Section("Estilo de Vida") {
                Toggle("Tabaquismo", isOn: $viewModel.smokingStatus)
                Toggle("Consumo de alcohol", isOn: $viewModel.alcoholUse)
                Toggle("Consumo de drogas", isOn: $viewModel.drugUse)
                Toggle("Chequeos médicos de rutina", isOn: $viewModel.routineCheckups)
            }

            // MARK: - Antecedentes Familiares
            Section("Antecedentes Familiares") {
                Toggle("Hipertensión arterial (HTA)", isOn: $viewModel.familyHistoryHTA)
                Toggle("ACV", isOn: $viewModel.familyHistoryACV)
                Toggle("Cáncer", isOn: $viewModel.familyHistoryCancer)
                Toggle("Diabetes", isOn: $viewModel.familyHistoryDiabetes)
                Toggle("Enfermedad cardíaca", isOn: $viewModel.familyHistoryHeartDisease)
                Toggle("Salud mental", isOn: $viewModel.familyHistoryMentalHealth)

                TextField("Otros antecedentes", text: $viewModel.familyHistoryOther)
            }
        }
        .navigationTitle("Historia Clínica")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    saveMedicalHistory()
                }
            }
        }
        .sheet(isPresented: $showingMedicationPicker) {
            MedicationPickerSheet(selectedMedications: $selectedMedications)
        }
        .sheet(item: $infoMedication) { medication in
            NavigationStack {
                MedicationInfoSheetView(medication: medication)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") {
                                infoMedication = nil
                            }
                        }
                    }
            }
        }
        // VM se carga en init. Medicaciones se leen acá porque requieren
        // acceso al grafo SwiftData que puede no estar listo en init.
        .onAppear {
            if selectedMedications.isEmpty && !(patient.currentMedications ?? []).isEmpty {
                selectedMedications = uniqueMedications(patient.currentMedications ?? [])
                initialSelectedMedicationIDs = Set(selectedMedications.map(\.id))
                didTouchMedicationSelection = false
            }
        }
        .onChange(of: Set(selectedMedications.map(\.id))) { _, newValue in
            didTouchMedicationSelection = newValue != initialSelectedMedicationIDs
        }
    }

    // MARK: - Helpers

    private var sortedSelectedMedications: [Medication] {
        selectedMedications.sorted {
            if $0.principioActivo.caseInsensitiveCompare($1.principioActivo) == .orderedSame {
                return $0.nombreComercial.localizedCaseInsensitiveCompare($1.nombreComercial) == .orderedAscending
            }
            return $0.principioActivo.localizedCaseInsensitiveCompare($1.principioActivo) == .orderedAscending
        }
    }

    private var bmiColor: Color {
        guard let bmi = viewModel.bmi, let category = BMICategory(bmi: bmi) else { return .secondary }
        return category.color
    }

    private func removeMedication(_ medication: Medication) {
        selectedMedications.removeAll { $0.id == medication.id }
    }

    private func uniqueMedications(_ medications: [Medication]) -> [Medication] {
        var seen = Set<UUID>()
        var unique: [Medication] = []

        for medication in medications {
            guard seen.insert(medication.id).inserted else { continue }
            unique.append(medication)
        }

        return unique
    }

    private func saveMedicalHistory() {
        // Crear registro histórico ANTES de actualizar,
        // porque la detección de cambios compara VM vs paciente actual.
        viewModel.createAnthropometricRecordIfNeeded(for: patient, in: modelContext)

        let uniqueSelection = uniqueMedications(sortedSelectedMedications)
        patient.currentMedications = uniqueSelection

        if uniqueSelection.isEmpty {
            // Compatibilidad: si no se toco el selector, conservar texto legacy.
            if didTouchMedicationSelection {
                viewModel.currentMedication = ""
            } else {
                viewModel.currentMedication = patient.currentMedication
            }
        } else {
            viewModel.currentMedication = uniqueSelection
                .map(\.summaryLabel)
                .joined(separator: " · ")
        }

        viewModel.update(patient)
        dismiss()
    }
}

private struct SelectedMedicationRow: View {

    let medication: Medication
    let onRemove: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.primaryDisplayName)
                    .font(.body)
                    .fontWeight(.semibold)

                Text(medication.secondaryDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onInfo()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
        }
    }
}
