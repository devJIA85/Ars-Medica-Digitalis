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
import Charts

struct PatientMedicalHistoryView: View {

    @Environment(\.modelContext) private var modelContext

    let patient: Patient
    let professional: Professional

    @State private var showingEditForm: Bool = false
    @State private var showingGenogram: Bool = false
    @State private var showingNewTreatment: Bool = false
    @State private var showingNewHospitalization: Bool = false
    @State private var infoMedication: Medication? = nil

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
                let meds = sortedCurrentMedications
                if meds.isEmpty {
                    if patient.currentMedication.isEmpty {
                        Text("Sin medicación registrada")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(patient.currentMedication)
                    }
                } else {
                    ForEach(meds) { medication in
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
                                infoMedication = medication
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // MARK: - Antropometría
            Section("Antropometría") {
                let records = patient.anthropometricRecords ?? []
                let latestMeasurementDate = records.map(\.recordDate).max()

                if patient.weightKg > 0 {
                    LabeledContent("Peso", value: "\(String(format: "%.1f", patient.weightKg)) kg")
                }
                if patient.heightCm > 0 {
                    LabeledContent("Altura", value: "\(String(format: "%.0f", patient.heightCm)) cm")
                }
                if patient.waistCm > 0 {
                    LabeledContent("Cintura", value: "\(String(format: "%.0f", patient.waistCm)) cm")
                }

                // Gauge visual del IMC — reemplaza el badge de texto
                if let bmi = patient.bmi {
                    BMIGaugeView(
                        bmiValue: bmi,
                        lastMeasurementDate: latestMeasurementDate
                    )
                }

                // Tendencia temporal: solo si hay 2+ registros históricos
                if records.count >= 2 {
                    WeightTrendChartView(records: records)
                } else if records.count == 1 {
                    // Hint para que el profesional sepa que la tendencia aparecerá
                    Text("Guardá mediciones en diferentes fechas para ver la tendencia")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    let sortedTreatments = treatments.sorted(by: { $0.createdAt > $1.createdAt })
                    ForEach(Array(sortedTreatments.enumerated()), id: \.element.id) { index, treatment in
                        NavigationLink {
                            PriorTreatmentFormView(patient: patient, treatment: treatment)
                        } label: {
                            PriorTreatmentRow(
                                treatment: treatment,
                                isFirst: index == 0,
                                isLast: index == sortedTreatments.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        deleteTreatments(at: indexSet, from: sortedTreatments)
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
                    let sortedHospitalizations = hospitalizations.sorted(by: { $0.admissionDate > $1.admissionDate })
                    ForEach(Array(sortedHospitalizations.enumerated()), id: \.element.id) { index, hosp in
                        NavigationLink {
                            HospitalizationFormView(patient: patient, hospitalization: hosp)
                        } label: {
                            HospitalizationRow(
                                hospitalization: hosp,
                                isFirst: index == 0,
                                isLast: index == sortedHospitalizations.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        deleteHospitalizations(at: indexSet, from: sortedHospitalizations)
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
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditForm = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Editar historia clínica")
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
    }

    // MARK: - Helpers

    private func lifestyleRow(_ label: String, systemImage: String, isActive: Bool) -> some View {
        Label(label, systemImage: systemImage)
            .foregroundStyle(isActive ? .primary : .secondary)
            .badge(isActive ? "Sí" : "No")
    }

    private var sortedCurrentMedications: [Medication] {
        (patient.currentMedications ?? []).sorted {
            if $0.principioActivo.caseInsensitiveCompare($1.principioActivo) == .orderedSame {
                return $0.nombreComercial.localizedCaseInsensitiveCompare($1.nombreComercial) == .orderedAscending
            }
            return $0.principioActivo.localizedCaseInsensitiveCompare($1.principioActivo) == .orderedAscending
        }
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
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            TimelineIndicator(isFirst: isFirst, isLast: isLast)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(treatment.createdAt.esShortDateAbbrev())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(treatmentTypeLabel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: AppSpacing.sm) {
                    if !treatment.durationDescription.trimmed.isEmpty {
                        Text(treatment.durationDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    treatmentBadge
                }

                if !treatment.observations.trimmed.isEmpty {
                    Text(treatment.observations)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
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
        default: treatment.outcome.trimmed.isEmpty ? "Registrado" : treatment.outcome.capitalized
        }
    }

    private var treatmentBadge: some View {
        Text(outcomeLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(outcomeTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(outcomeTint.opacity(0.14), in: Capsule())
    }

    private var outcomeTint: Color {
        switch treatment.outcome {
        case "alta": .green
        case "abandono": .orange
        case "derivación": .blue
        case "en curso": .indigo
        default: .secondary
        }
    }
}

// MARK: - Fila de internación

private struct HospitalizationRow: View {
    let hospitalization: Hospitalization
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            TimelineIndicator(isFirst: isFirst, isLast: isLast)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(hospitalization.admissionDate.esShortDateAbbrev())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                HStack(spacing: AppSpacing.sm) {
                    Text("Internación")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    Text("Previa")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.7), in: Capsule())
                }

                if !hospitalization.durationDescription.trimmed.isEmpty {
                    Text(hospitalization.durationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !hospitalization.observations.trimmed.isEmpty {
                    Text(hospitalization.observations)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct TimelineIndicator: View {
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.quaternary)
                .frame(width: 2, height: isFirst ? 0 : 10)
                .opacity(isFirst ? 0 : 1)

            Circle()
                .fill(.secondary.opacity(0.7))
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(.quaternary)
                .frame(width: 2)
                .frame(minHeight: isLast ? 0 : 24, maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 12)
    }
}
