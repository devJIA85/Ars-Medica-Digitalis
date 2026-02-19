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

    var body: some View {
        List {
            // MARK: - Datos de la Sesión
            Section("Datos de la Sesión") {
                LabeledContent("Fecha", value: session.sessionDate.formatted(date: .long, time: .shortened))
                LabeledContent("Modalidad", value: sessionTypeLabel)
                LabeledContent("Duración", value: "\(session.durationMinutes) min")
                LabeledContent("Estado", value: statusLabel)

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
                Section("Diagnósticos CIE-11") {
                    ForEach(diagnoses) { diagnosis in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                diagnosis.icdTitleEs.isEmpty
                                    ? diagnosis.icdTitle
                                    : diagnosis.icdTitleEs
                            )
                            .font(.body)

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                SessionFormView(patient: patient, session: session)
            }
        }
    }

    // MARK: - Labels

    private var sessionTypeLabel: String {
        switch session.sessionType {
        case "presencial": "Presencial"
        case "videollamada": "Videollamada"
        case "telefónica": "Telefónica"
        default: session.sessionType.capitalized
        }
    }

    private var statusLabel: String {
        switch session.status {
        case "programada": "Programada"
        case "completada": "Completada"
        case "cancelada": "Cancelada"
        default: session.status.capitalized
        }
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
    let container = try! ModelContainer(
        for: Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self, PriorTreatment.self, Hospitalization.self, AnthropometricRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
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
