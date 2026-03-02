//
//  SessionDetailView.swift
//  Ars Medica Digitalis
//
//  Vista de lectura de una sesión clínica (HU-04, HU-05).
//  Muestra todos los campos de la sesión y los diagnósticos CIE-11
//  persistidos como snapshot — nunca llama a la API externa.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {

    let session: Session
    let patient: Patient
    let professional: Professional

    @State private var showingEdit: Bool = false
    @State private var showingStatusPicker: Bool = false
    @State private var showAllDiagnoses = false

    private static let diagnosisVisibleLimit = 3

    var body: some View {
        List {
            // MARK: - Datos de la Sesión
            Section("Datos de la Sesión") {
                LabeledContent("Fecha", value: session.sessionDate.formatted(date: .long, time: .shortened))
                LabeledContent("Modalidad", value: sessionTypeLabel)
                LabeledContent("Duración", value: "\(session.durationMinutes) min")
                LabeledContent("Estado") {
                    Button {
                        showingStatusPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: currentStatusMapping.icon)
                            Text(currentStatusMapping.label)
                        }
                        .foregroundStyle(currentStatusMapping.tint)
                    }
                    .buttonStyle(.plain)
                }

                if !session.chiefComplaint.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Motivo de consulta")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(session.chiefComplaint)
                    }
                }
            }

            // MARK: - Diagnósticos CIE-11
            if let diagnoses = session.diagnoses, !diagnoses.isEmpty {
                Section {
                    let visible = showAllDiagnoses
                        ? diagnoses
                        : Array(diagnoses.prefix(Self.diagnosisVisibleLimit))

                    ForEach(visible) { diagnosis in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(diagnosis.displayTitle)
                                .font(.body)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                if !diagnosis.icdCode.isEmpty {
                                    Text(diagnosis.icdCode)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }

                                Text(diagnosisTypeLabel(diagnosis.diagnosisType))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if !diagnosis.clinicalNotes.isEmpty {
                                Text(diagnosis.clinicalNotes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    let hiddenCount = diagnoses.count - Self.diagnosisVisibleLimit
                    if hiddenCount > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllDiagnoses.toggle()
                            }
                        } label: {
                            Label(
                                showAllDiagnoses
                                    ? "Mostrar menos"
                                    : "Ver \(hiddenCount) diagnóstico\(hiddenCount == 1 ? "" : "s") más",
                                systemImage: showAllDiagnoses ? "chevron.up" : "chevron.down"
                            )
                            .font(.footnote)
                            .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("Diagnósticos CIE-11")
                        Text("\(diagnoses.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
            }

            // MARK: - Notas y Plan
            if !session.notes.isEmpty || !session.treatmentPlan.isEmpty {
                Section("Notas y Plan") {
                    if !session.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notas clínicas")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(session.notes)
                        }
                    }

                    if !session.treatmentPlan.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Plan de tratamiento")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(session.treatmentPlan)
                        }
                    }
                }
            }

            // MARK: - Trazabilidad
            Section {
                LabeledContent("Creado", value: session.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Modificado", value: session.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .navigationTitle("Sesión")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Editar sesión")
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                SessionFormView(patient: patient, session: session)
            }
        }
        .confirmationDialog("Cambiar estado", isPresented: $showingStatusPicker, titleVisibility: .visible) {
            if session.status != SessionStatusMapping.programada.rawValue {
                Button(SessionStatusMapping.programada.label) {
                    applyStatusChange(.programada)
                }
            }
            if session.status != SessionStatusMapping.completada.rawValue {
                Button(SessionStatusMapping.completada.label) {
                    applyStatusChange(.completada)
                }
            }
            if session.status != SessionStatusMapping.cancelada.rawValue {
                Button(SessionStatusMapping.cancelada.label, role: .destructive) {
                    applyStatusChange(.cancelada)
                }
            }
        }
    }

    // MARK: - Labels

    private var sessionTypeLabel: String {
        SessionTypeMapping(sessionTypeRawValue: session.sessionType)?.label
        ?? session.sessionType.capitalized
    }

    // MARK: - Status

    private var currentStatusMapping: SessionStatusMapping {
        SessionStatusMapping(sessionStatusRawValue: session.status) ?? .completada
    }

    private func applyStatusChange(_ newStatus: SessionStatusMapping) {
        session.status = newStatus.rawValue
        session.updatedAt = Date()
    }

    private func diagnosisTypeLabel(_ type: String) -> String {
        switch type {
        case "principal": "Principal"
        case "secundario": "Secundario"
        case "diferencial": "Diferencial"
        default: type.capitalized
        }
    }
}

#Preview {
    let container = ModelContainer.preview
    let professional = Professional(fullName: "Dr. Test", licenseNumber: "MN 999", specialty: "Psicología")
    container.mainContext.insert(professional)

    let patient = Patient(firstName: "Ana", lastName: "García", professional: professional)
    container.mainContext.insert(patient)

    let session = Session(
        notes: "Paciente refiere aumento de síntomas en las últimas 2 semanas.",
        chiefComplaint: "Ansiedad generalizada con episodios de pánico",
        treatmentPlan: "Continuar terapia cognitivo-conductual. Evaluar derivación a psiquiatría.",
        patient: patient
    )
    container.mainContext.insert(session)

    let diagnosis = Diagnosis(
        icdCode: "6B00",
        icdTitle: "Generalised anxiety disorder",
        icdTitleEs: "Trastorno de ansiedad generalizada",
        icdURI: "http://id.who.int/icd/entity/1712535455",
        session: session
    )
    container.mainContext.insert(diagnosis)

    return NavigationStack {
        SessionDetailView(session: session, patient: patient, professional: professional)
    }
    .modelContainer(container)
}
