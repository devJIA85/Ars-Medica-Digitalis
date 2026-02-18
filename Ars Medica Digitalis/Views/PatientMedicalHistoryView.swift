//
//  PatientMedicalHistoryView.swift
//  Ars Medica Digitalis
//
//  Vista de lectura de la historia clínica completa del paciente.
//  Muestra medicación, antropometría, estilo de vida, antecedentes
//  familiares, genograma, tratamientos previos e internaciones.
//  Accesible desde PatientDetailView via NavigationLink.
//

import SwiftUI
import SwiftData
import PencilKit

struct PatientMedicalHistoryView: View {

    @Environment(\.modelContext) private var modelContext

    let patient: Patient
    let professional: Professional

    @State private var showingEditForm: Bool = false
    @State private var showingGenogram: Bool = false
    @State private var showingNewTreatment: Bool = false
    @State private var showingNewHospitalization: Bool = false

    // Binding local para el genograma
    @State private var genogramData: Data? = nil

    var body: some View {
        List {
            // MARK: - Nº de Historia Clínica
            if !patient.medicalRecordNumber.isEmpty {
                Section {
                    LabeledContent("Nº de HC", value: patient.medicalRecordNumber)
                        .font(.body.monospaced())
                }
            }

            // MARK: - Medicación Actual
            Section("Medicación Actual") {
                if patient.currentMedication.isEmpty {
                    Text("Sin medicación registrada")
                        .foregroundStyle(.secondary)
                } else {
                    Text(patient.currentMedication)
                }
            }

            // MARK: - Antropometría
            Section("Antropometría") {
                if patient.weightKg > 0 {
                    LabeledContent("Peso", value: "\(String(format: "%.1f", patient.weightKg)) kg")
                }
                if patient.heightCm > 0 {
                    LabeledContent("Altura", value: "\(String(format: "%.0f", patient.heightCm)) cm")
                }
                if patient.waistCm > 0 {
                    LabeledContent("Cintura", value: "\(String(format: "%.0f", patient.waistCm)) cm")
                }
                if let bmi = patient.bmi {
                    LabeledContent("IMC") {
                        Text("\(String(format: "%.1f", bmi)) — \(bmiCategory(bmi))")
                            .fontWeight(.semibold)
                            .foregroundStyle(bmiColor(bmi))
                    }
                }

                if patient.weightKg == 0 && patient.heightCm == 0 {
                    Text("Sin datos antropométricos")
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Estilo de Vida
            Section("Estilo de Vida") {
                lifestyleRow("Tabaquismo", systemImage: "smoke", isActive: patient.smokingStatus)
                lifestyleRow("Alcohol", systemImage: "wineglass", isActive: patient.alcoholUse)
                lifestyleRow("Drogas", systemImage: "pill", isActive: patient.drugUse)
                lifestyleRow("Chequeos de rutina", systemImage: "heart.text.clipboard", isActive: patient.routineCheckups)
            }

            // MARK: - Antecedentes Familiares
            Section("Antecedentes Familiares") {
                let activeHistory = activeFamilyHistory
                if activeHistory.isEmpty && patient.familyHistoryOther.isEmpty {
                    Text("Sin antecedentes familiares registrados")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeHistory, id: \.self) { item in
                        Label(item, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.primary)
                    }
                    if !patient.familyHistoryOther.isEmpty {
                        Label(patient.familyHistoryOther, systemImage: "exclamationmark.triangle")
                    }
                }
            }

            // MARK: - Genograma
            Section("Genograma") {
                if let data = patient.genogramData,
                   let drawing = try? PKDrawing(data: data) {
                    // Preview del dibujo
                    // Scale 2.0 como default razonable para retina.
                    // UIScreen.main está deprecated en iOS 26.
                    Image(uiImage: drawing.image(
                        from: drawing.bounds,
                        scale: 2.0
                    ))
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .onTapGesture {
                        genogramData = patient.genogramData
                        showingGenogram = true
                    }
                } else {
                    Button {
                        genogramData = patient.genogramData
                        showingGenogram = true
                    } label: {
                        Label("Crear genograma", systemImage: "pencil.and.scribble")
                    }
                }
            }

            // MARK: - Tratamientos Previos
            Section("Tratamientos Previos") {
                let treatments = patient.priorTreatments ?? []
                if treatments.isEmpty {
                    Text("Sin tratamientos previos registrados")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(treatments.sorted(by: { $0.createdAt > $1.createdAt })) { treatment in
                        NavigationLink {
                            PriorTreatmentFormView(patient: patient, treatment: treatment)
                        } label: {
                            PriorTreatmentRow(treatment: treatment)
                        }
                    }
                    .onDelete { indexSet in
                        deleteTreatments(at: indexSet, from: treatments.sorted(by: { $0.createdAt > $1.createdAt }))
                    }
                }

                Button {
                    showingNewTreatment = true
                } label: {
                    Label("Agregar tratamiento", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }
            }

            // MARK: - Internaciones Previas
            Section("Internaciones Previas") {
                let hospitalizations = patient.hospitalizations ?? []
                if hospitalizations.isEmpty {
                    Text("Sin internaciones previas registradas")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hospitalizations.sorted(by: { $0.admissionDate > $1.admissionDate })) { hosp in
                        NavigationLink {
                            HospitalizationFormView(patient: patient, hospitalization: hosp)
                        } label: {
                            HospitalizationRow(hospitalization: hosp)
                        }
                    }
                    .onDelete { indexSet in
                        deleteHospitalizations(at: indexSet, from: hospitalizations.sorted(by: { $0.admissionDate > $1.admissionDate }))
                    }
                }

                Button {
                    showingNewHospitalization = true
                } label: {
                    Label("Agregar internación", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }
            }
        }
        .navigationTitle("Historia Clínica")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") {
                    showingEditForm = true
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationStack {
                PatientMedicalHistoryFormView(patient: patient)
            }
        }
        .sheet(isPresented: $showingGenogram, onDismiss: {
            // Guardar genograma al cerrar el canvas
            patient.genogramData = genogramData
            patient.updatedAt = Date()
        }) {
            NavigationStack {
                GenogramCanvasView(drawingData: $genogramData)
                    .navigationTitle("Genograma")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") {
                                showingGenogram = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingNewTreatment) {
            NavigationStack {
                PriorTreatmentFormView(patient: patient)
            }
        }
        .sheet(isPresented: $showingNewHospitalization) {
            NavigationStack {
                HospitalizationFormView(patient: patient)
            }
        }
    }

    // MARK: - Helpers

    private func lifestyleRow(_ label: String, systemImage: String, isActive: Bool) -> some View {
        Label(label, systemImage: systemImage)
            .foregroundStyle(isActive ? .primary : .secondary)
            .badge(isActive ? "Sí" : "No")
    }

    private var activeFamilyHistory: [String] {
        var items: [String] = []
        if patient.familyHistoryHTA { items.append("Hipertensión arterial") }
        if patient.familyHistoryACV { items.append("ACV") }
        if patient.familyHistoryCancer { items.append("Cáncer") }
        if patient.familyHistoryDiabetes { items.append("Diabetes") }
        if patient.familyHistoryHeartDisease { items.append("Enfermedad cardíaca") }
        if patient.familyHistoryMentalHealth { items.append("Salud mental") }
        return items
    }

    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: .orange
        case 18.5..<25: .green
        case 25..<30: .orange
        default: .red
        }
    }

    private func bmiCategory(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: "Bajo peso"
        case 18.5..<25: "Normal"
        case 25..<30: "Sobrepeso"
        default: "Obesidad"
        }
    }

    private func deleteTreatments(at offsets: IndexSet, from sorted: [PriorTreatment]) {
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    private func deleteHospitalizations(at offsets: IndexSet, from sorted: [Hospitalization]) {
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

// MARK: - Fila de tratamiento previo

private struct PriorTreatmentRow: View {
    let treatment: PriorTreatment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(treatmentTypeLabel)
                .font(.body)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                if !treatment.durationDescription.isEmpty {
                    Text(treatment.durationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !treatment.outcome.isEmpty {
                    Text(outcomeLabel)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    private var treatmentTypeLabel: String {
        switch treatment.treatmentType {
        case "psicoterapia": "Psicoterapia"
        case "psiquiatría": "Psiquiatría"
        case "otro": "Otro"
        default: treatment.treatmentType.capitalized
        }
    }

    private var outcomeLabel: String {
        switch treatment.outcome {
        case "alta": "Alta"
        case "abandono": "Abandono"
        case "derivación": "Derivación"
        case "en curso": "En curso"
        default: treatment.outcome.capitalized
        }
    }
}

// MARK: - Fila de internación

private struct HospitalizationRow: View {
    let hospitalization: Hospitalization

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hospitalization.admissionDate.formatted(date: .abbreviated, time: .omitted))
                .font(.body)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                if !hospitalization.durationDescription.isEmpty {
                    Text(hospitalization.durationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !hospitalization.observations.isEmpty {
                    Text(hospitalization.observations)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
