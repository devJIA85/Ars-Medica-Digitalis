//
//  PatientDetailView.swift
//  Ars Medica Digitalis
//
//  Vista de perfil del paciente con historial de sesiones clínicas,
//  acceso a edición y baja lógica/restauración (HU-02 a HU-05).
//

import SwiftUI
import SwiftData

struct PatientDetailView: View {

    @Environment(\.modelContext) private var modelContext

    let patient: Patient
    let professional: Professional

    @State private var showingEdit: Bool = false
    @State private var showingNewSession: Bool = false
    @State private var showingDeleteConfirmation: Bool = false

    var body: some View {
        List {
            // MARK: - Datos demográficos

            Section("Datos Personales") {
                LabeledContent("Nombre", value: patient.fullName)
                LabeledContent("Fecha de Nacimiento", value: patient.dateOfBirth.formatted(date: .long, time: .omitted))

                if !patient.biologicalSex.isEmpty {
                    LabeledContent("Sexo Biológico", value: patient.biologicalSex.capitalized)
                }

                if !patient.nationalId.isEmpty {
                    LabeledContent("Documento", value: patient.nationalId)
                }
            }

            if !patient.email.isEmpty || !patient.phoneNumber.isEmpty || !patient.address.isEmpty {
                Section("Contacto") {
                    if !patient.email.isEmpty {
                        LabeledContent("Email", value: patient.email)
                    }
                    if !patient.phoneNumber.isEmpty {
                        LabeledContent("Teléfono", value: patient.phoneNumber)
                    }
                    if !patient.address.isEmpty {
                        LabeledContent("Dirección", value: patient.address)
                    }
                }
            }

            // MARK: - Historia Clínica (HU-04, HU-05)

            Section("Historia Clínica") {
                let sessions = (patient.sessions ?? [])
                    .sorted { $0.sessionDate > $1.sessionDate }

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Sin sesiones",
                        systemImage: "doc.text",
                        description: Text("Creá la primera sesión para este paciente.")
                    )
                } else {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(
                                session: session,
                                patient: patient,
                                professional: professional
                            )
                        } label: {
                            SessionRowView(session: session)
                        }
                    }
                }

                Button {
                    showingNewSession = true
                } label: {
                    Label("Nueva Sesión", systemImage: "plus.circle")
                }
            }

            // MARK: - Estado y trazabilidad

            Section("Información") {
                LabeledContent("Creado", value: patient.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Última modificación", value: patient.updatedAt.formatted(date: .abbreviated, time: .shortened))

                if !patient.isActive, let deletedAt = patient.deletedAt {
                    LabeledContent("Fecha de baja") {
                        Text(deletedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.red)
                    }
                }
            }

            // MARK: - Acciones

            Section {
                if patient.isActive {
                    Button("Dar de Baja", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } else {
                    Button("Restaurar Paciente") {
                        patient.deletedAt = nil
                        patient.updatedAt = Date()
                    }
                }
            }
        }
        .navigationTitle(patient.fullName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                PatientFormView(professional: professional, patient: patient)
            }
        }
        .sheet(isPresented: $showingNewSession) {
            NavigationStack {
                SessionFormView(patient: patient)
            }
        }
        .confirmationDialog(
            "¿Dar de baja a este paciente?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Dar de Baja", role: .destructive) {
                patient.deletedAt = Date()
                patient.updatedAt = Date()
            }
        } message: {
            Text("El paciente desaparecerá de la lista principal. Su historia clínica se conservará íntegra.")
        }
    }
}

// MARK: - Fila de sesión en el historial

private struct SessionRowView: View {

    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.sessionDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                Text(sessionTypeLabel)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            if !session.chiefComplaint.isEmpty {
                Text(session.chiefComplaint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let diagnoses = session.diagnoses, !diagnoses.isEmpty {
                Text(
                    diagnoses
                        .compactMap { $0.icdCode.isEmpty ? nil : $0.icdCode }
                        .joined(separator: ", ")
                )
                .font(.caption2)
                .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 2)
    }

    private var sessionTypeLabel: String {
        switch session.sessionType {
        case "presencial": "Presencial"
        case "videollamada": "Video"
        case "telefónica": "Tel."
        default: session.sessionType
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let professional = Professional(
        fullName: "Dr. Test",
        licenseNumber: "MN 999",
        specialty: "Psicología"
    )
    container.mainContext.insert(professional)

    let patient = Patient(
        firstName: "Ana",
        lastName: "García",
        email: "ana@example.com",
        phoneNumber: "+54 11 1234-5678",
        professional: professional
    )
    container.mainContext.insert(patient)

    return NavigationStack {
        PatientDetailView(patient: patient, professional: professional)
    }
    .modelContainer(container)
}
