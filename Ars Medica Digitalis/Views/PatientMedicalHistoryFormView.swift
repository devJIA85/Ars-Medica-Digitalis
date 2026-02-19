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

    @Bindable var viewModel = PatientViewModel()

    var body: some View {
        Form {
            // MARK: - Medicación Actual
            Section("Medicación Actual") {
                TextField(
                    "Medicación actual del paciente...",
                    text: $viewModel.currentMedication,
                    axis: .vertical
                )
                .lineLimit(3...8)
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
                        Text(String(format: "%.1f — %@", bmi, viewModel.bmiCategory))
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
                    // Crear registro histórico ANTES de actualizar,
                    // porque la detección de cambios compara VM vs paciente actual
                    viewModel.createAnthropometricRecordIfNeeded(for: patient, in: modelContext)
                    viewModel.update(patient)
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.load(from: patient)
        }
    }

    // MARK: - Helpers

    private var bmiColor: Color {
        guard let bmi = viewModel.bmi else { return .secondary }
        switch bmi {
        case ..<18.5: return .orange
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
}
