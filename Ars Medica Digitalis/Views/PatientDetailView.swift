//
//  PatientDetailView.swift
//  Ars Medica Digitalis
//
//  Vista de perfil del paciente con historial de sesiones clínicas,
//  diagnósticos vigentes, historia clínica y acciones (HU-02 a HU-05).
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
            // MARK: - Header con foto y nombre

            Section {
                HStack(spacing: 16) {
                    // Avatar reutilizable — reemplaza lógica inline duplicada
                    PatientAvatarView(
                        photoData: patient.photoData,
                        genderHint: patient.gender.isEmpty ? patient.biologicalSex : patient.gender,
                        size: 64
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(patient.fullName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("\(patient.age) años")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let nextBirthday = patient.nextBirthday {
                            Text("Cumple el \(nextBirthday.esDayMonthAbbrev())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: - Datos Personales

            Section {
                IconLabeledValueRow(
                    title: "Nacimiento",
                    systemImage: "calendar",
                    value: patient.dateOfBirth.esShortDateAbbrev()
                )

                if !patient.biologicalSex.isEmpty {
                    IconLabeledValueRow(
                        title: "Sexo Biológico",
                        systemImage: "figure.stand",
                        value: patient.biologicalSex.capitalized
                    )
                }

                if !patient.gender.isEmpty {
                    IconLabeledValueRow(
                        title: "Género",
                        systemImage: "person",
                        value: patient.gender.capitalized
                    )
                }

                if !patient.nationalId.isEmpty {
                    IconLabeledValueRow(
                        title: "Documento",
                        systemImage: "person.text.rectangle",
                        value: patient.nationalId
                    )
                }

                if !patient.nationality.isEmpty {
                    IconLabeledValueRow(
                        title: "Nacionalidad",
                        systemImage: "globe",
                        value: patient.nationality
                    )
                }

                if !patient.residenceCountry.isEmpty {
                    IconLabeledValueRow(
                        title: "País de Residencia",
                        systemImage: "mappin",
                        value: patient.residenceCountry
                    )
                }

                if !patient.occupation.isEmpty {
                    IconLabeledValueRow(
                        title: "Ocupación",
                        systemImage: "briefcase",
                        value: patient.occupation
                    )
                }

                if !patient.educationLevel.isEmpty {
                    IconLabeledValueRow(
                        title: "Nivel Académico",
                        systemImage: "graduationcap",
                        value: patient.educationLevel.capitalized
                    )
                }

                if !patient.maritalStatus.isEmpty {
                    IconLabeledValueRow(
                        title: "Estado Civil",
                        systemImage: "heart",
                        value: patient.maritalStatus.capitalized
                    )
                }
            } header: {
                Label("Datos Personales", systemImage: "person.crop.rectangle")
            }

            // MARK: - Cobertura Médica

            if !patient.healthInsurance.isEmpty || !patient.insuranceMemberNumber.isEmpty {
                Section {
                    if !patient.healthInsurance.isEmpty {
                        IconLabeledValueRow(
                            title: "Obra Social",
                            systemImage: "cross.case",
                            value: patient.healthInsurance
                        )
                    }
                    if !patient.insuranceMemberNumber.isEmpty {
                        IconLabeledValueRow(
                            title: "Nº Afiliado",
                            systemImage: "number",
                            value: patient.insuranceMemberNumber
                        )
                    }
                    if !patient.insurancePlan.isEmpty {
                        IconLabeledValueRow(
                            title: "Plan",
                            systemImage: "doc.text",
                            value: patient.insurancePlan
                        )
                    }
                } header: {
                    Label("Cobertura Médica", systemImage: "cross.case")
                }
            }

            // MARK: - Contacto

            if hasContactData {
                Section {
                    if !patient.email.isEmpty {
                        IconLabeledValueRow(
                            title: "Email",
                            systemImage: "envelope",
                            value: patient.email
                        )
                    }
                    if !patient.phoneNumber.isEmpty {
                        IconLabeledValueRow(
                            title: "Teléfono",
                            systemImage: "phone",
                            value: patient.phoneNumber
                        )
                    }
                    if !patient.address.isEmpty {
                        IconLabeledValueRow(
                            title: "Dirección",
                            systemImage: "mappin.and.ellipse",
                            value: patient.address
                        )
                    }

                    // Contacto de emergencia
                    if !patient.emergencyContactName.isEmpty {
                        IconLabeledValueRow(
                            title: "Emergencia",
                            systemImage: "exclamationmark.triangle",
                            value: emergencyContactSummary
                        )
                    }
                } header: {
                    Label("Contacto", systemImage: "person.crop.circle.badge.checkmark")
                }
            }

            // MARK: - Diagnósticos Vigentes

            Section {
                let diagnoses = patient.activeDiagnoses ?? []

                if diagnoses.isEmpty {
                    Text("Sin diagnósticos vigentes")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(diagnoses) { diagnosis in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    diagnosis.icdTitleEs.isEmpty
                                        ? diagnosis.icdTitle
                                        : diagnosis.icdTitleEs
                                )
                                .font(.body)

                                if !diagnosis.icdCode.isEmpty {
                                    Text(diagnosis.icdCode)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                removeActiveDiagnosis(diagnosis)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                NavigationLink {
                    ICD11SearchView(
                        alreadySelected: activeDiagnosesAsDTO,
                        onSelect: { result in
                            addActiveDiagnosis(result)
                        }
                    )
                } label: {
                    Label("Agregar Diagnóstico", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }
            } header: {
                Label("Diagnósticos Vigentes", systemImage: "stethoscope")
            }

            // MARK: - Historia Clínica (link a vista dedicada)

            Section {
                NavigationLink {
                    PatientMedicalHistoryView(
                        patient: patient,
                        professional: professional
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Ver Historia Clínica", systemImage: "list.clipboard")
                            .font(.body)

                        // Resumen compacto
                        HStack(spacing: 12) {
                            if !patient.medicalRecordNumber.isEmpty {
                                Text(patient.medicalRecordNumber)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let bmi = patient.bmi {
                                Text("IMC \(String(format: "%.1f", bmi))")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: Capsule())
                            }
                            if !patient.currentMedication.isEmpty {
                                Text(patient.currentMedication)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } header: {
                Label("Historia Clínica", systemImage: "heart.text.clipboard")
            }

            // MARK: - Sesiones

            Section {
                let sessions = (patient.sessions ?? [])
                    .sorted { $0.sessionDate > $1.sessionDate }

                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Sin sesiones",
                        systemImage: "calendar.badge.exclamationmark",
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
            } header: {
                Label("Sesiones", systemImage: "clock.arrow.circlepath")
            }

            // MARK: - Trazabilidad

            Section {
                IconLabeledValueRow(
                    title: "Creado",
                    systemImage: "calendar.badge.clock",
                    value: patient.createdAt.esShortDate()
                )
                IconLabeledValueRow(
                    title: "Modificado",
                    systemImage: "pencil.and.outline",
                    value: patient.updatedAt.esShortDateTime()
                )

                if !patient.isActive, let deletedAt = patient.deletedAt {
                    IconLabeledValueRow(
                        title: "Fecha de baja",
                        systemImage: "person.crop.circle.badge.xmark",
                        value: deletedAt.esShortDateTime(),
                        valueStyle: .red
                    )
                }
            } header: {
                Label("Información", systemImage: "info.circle")
            }

            // MARK: - Acciones

            Section {
                if patient.isActive {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Dar de Baja", systemImage: "person.crop.circle.badge.xmark")
                    }
                } else {
                    Button {
                        patient.deletedAt = nil
                        patient.updatedAt = Date()
                    } label: {
                        Label("Restaurar Paciente", systemImage: "arrow.counterclockwise")
                    }
                }
            } header: {
                Label("Acciones", systemImage: "slider.horizontal.3")
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

    // MARK: - Helpers

    private var hasContactData: Bool {
        !patient.email.isEmpty
        || !patient.phoneNumber.isEmpty
        || !patient.address.isEmpty
        || !patient.emergencyContactName.isEmpty
    }

    private var emergencyContactSummary: String {
        var parts: [String] = [patient.emergencyContactName]
        if !patient.emergencyContactRelation.isEmpty {
            parts.append("(\(patient.emergencyContactRelation))")
        }
        if !patient.emergencyContactPhone.isEmpty {
            parts.append("— \(patient.emergencyContactPhone)")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Diagnósticos vigentes — helpers

    private var activeDiagnosesAsDTO: [ICD11SearchResult] {
        (patient.activeDiagnoses ?? []).map { diagnosis in
            ICD11SearchResult(
                id: diagnosis.icdURI,
                theCode: diagnosis.icdCode.isEmpty ? nil : diagnosis.icdCode,
                title: diagnosis.icdTitleEs.isEmpty
                    ? diagnosis.icdTitle
                    : diagnosis.icdTitleEs,
                chapter: nil,
                score: nil
            )
        }
    }

    private func addActiveDiagnosis(_ result: ICD11SearchResult) {
        let existing = patient.activeDiagnoses ?? []
        guard !existing.contains(where: { $0.icdURI == result.id }) else { return }

        let diagnosis = Diagnosis(
            icdCode: result.theCode ?? "",
            icdTitle: result.title,
            icdTitleEs: result.title,
            icdURI: result.id,
            icdVersion: "2024-01",
            patient: patient
        )
        modelContext.insert(diagnosis)
        patient.updatedAt = Date()
    }

    private func removeActiveDiagnosis(_ diagnosis: Diagnosis) {
        modelContext.delete(diagnosis)
        patient.updatedAt = Date()
    }
}

// MARK: - Fila de sesión en el historial

private struct SessionRowView: View {

    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.sessionDate.esShortDateTime())
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                SessionTypeBadge(
                    label: sessionTypeLabel,
                    systemImage: sessionTypeIcon,
                    tint: sessionTypeTint
                )
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

    private var sessionTypeIcon: String {
        switch session.sessionType {
        case "presencial": "person.2.wave.2"
        case "videollamada": "video"
        case "telefónica": "phone"
        default: "questionmark"
        }
    }

    private var sessionTypeTint: Color {
        switch session.sessionType {
        case "presencial": .teal
        case "videollamada": .indigo
        case "telefónica": .orange
        default: .secondary
        }
    }
}

private struct IconLabeledValueRow: View {
    let title: String
    let systemImage: String
    let value: String
    var valueStyle: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .foregroundStyle(valueStyle)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}

private struct SessionTypeBadge: View {
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.35), lineWidth: 0.5)
        )
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self, PriorTreatment.self, Hospitalization.self, AnthropometricRecord.self,
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

