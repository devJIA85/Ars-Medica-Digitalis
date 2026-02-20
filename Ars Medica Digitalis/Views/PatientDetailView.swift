//
//  PatientDetailView.swift
//  Ars Medica Digitalis
//
//  Perfil clínico del paciente con diseño en tarjetas Liquid Glass (iOS 26).
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
    @State private var isExportingPDF: Bool = false
    @State private var showingPDFShareSheet: Bool = false
    @State private var exportedPDFURL: URL? = nil
    @State private var exportErrorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileHeaderView(patient: patient)

                PersonalDataCard(patient: patient)

                if hasMedicalCoverageData {
                    MedicalCoverageCard(patient: patient)
                }

                if hasContactData {
                    ContactCard(patient: patient, emergencyContactSummary: emergencyContactSummary)
                }

                DiagnosesCard(
                    patient: patient,
                    diagnoses: patient.activeDiagnoses ?? [],
                    activeDiagnosesAsDTO: activeDiagnosesAsDTO,
                    onAddDiagnosis: addActiveDiagnosis,
                    onRemoveDiagnosis: removeActiveDiagnosis
                )

                MedicalHistoryCard(patient: patient, professional: professional)

                SessionsCard(
                    patient: patient,
                    professional: professional,
                    onCreateSession: { showingNewSession = true }
                )

                AuditInfoCard(patient: patient)

                PatientActionsCard(
                    isActive: patient.isActive,
                    onDeactivate: { showingDeleteConfirmation = true },
                    onRestore: {
                        patient.deletedAt = nil
                        patient.updatedAt = Date()
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle(patient.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    exportPatientPDF()
                } label: {
                    if isExportingPDF {
                        ProgressView()
                    } else {
                        Image(systemName: "doc.richtext")
                    }
                }
                .disabled(isExportingPDF)
            }

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
        .sheet(isPresented: $showingPDFShareSheet) {
            if let exportedPDFURL {
                PDFExportShareView(
                    fileURL: exportedPDFURL,
                    patientName: patient.fullName
                )
            }
        }
        .alert(
            "No se pudo exportar el PDF",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "Ocurrió un error al generar el archivo.")
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

    private var hasMedicalCoverageData: Bool {
        !patient.healthInsurance.isEmpty
        || !patient.insuranceMemberNumber.isEmpty
        || !patient.insurancePlan.isEmpty
    }

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
            parts.append(patient.emergencyContactPhone)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Diagnósticos vigentes

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

    private func exportPatientPDF() {
        guard !isExportingPDF else { return }
        isExportingPDF = true
        defer { isExportingPDF = false }

        do {
            let service = PatientPDFExportService()
            let fileURL = try service.export(patient: patient, professional: professional)
            exportedPDFURL = fileURL
            showingPDFShareSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Header

private struct ProfileHeaderView: View {
    let patient: Patient

    var body: some View {
        CardShell(hierarchy: .primary) {
            HStack(alignment: .center, spacing: 16) {
                PatientAvatarView(
                    photoData: patient.photoData,
                    firstName: patient.firstName,
                    lastName: patient.lastName,
                    genderHint: patient.gender.isEmpty ? patient.biologicalSex : patient.gender,
                    clinicalStatus: patient.clinicalStatus,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.fullName)
                        .font(.title3.bold())
                    Text(headerSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var headerSubtitle: String {
        if let nextBirthday = patient.nextBirthday {
            return "\(patient.age) años • Cumple \(nextBirthday.esDayMonthAbbrev())"
        }
        return "\(patient.age) años"
    }
}

// MARK: - Cards

private struct PersonalDataCard: View {
    let patient: Patient

    var body: some View {
        CardShell(title: "Datos Personales", systemImage: "person.text.rectangle") {
            VStack(spacing: 12) {
                DataRowView(
                    icon: "calendar",
                    title: "Nacimiento",
                    value: patient.dateOfBirth.esShortDateAbbrev()
                )

                if !patient.biologicalSex.isEmpty {
                    DataRowView(
                        icon: "figure.stand",
                        title: "Sexo Biológico",
                        value: patient.biologicalSex.capitalized
                    )
                }

                if !patient.gender.isEmpty {
                    DataRowView(
                        icon: "person.crop.square",
                        title: "Género",
                        value: patient.gender.capitalized
                    )
                }

                if !patient.nationalId.isEmpty {
                    DataRowView(
                        icon: "person.text.rectangle",
                        title: "Documento",
                        value: patient.nationalId
                    )
                }

                if !patient.nationality.isEmpty {
                    DataRowView(
                        icon: "globe",
                        title: "Nacionalidad",
                        value: patient.nationality
                    )
                }

                if !patient.residenceCountry.isEmpty {
                    DataRowView(
                        icon: "mappin.and.ellipse",
                        title: "País de Residencia",
                        value: patient.residenceCountry
                    )
                }

                if !patient.occupation.isEmpty {
                    DataRowView(
                        icon: "briefcase",
                        title: "Ocupación",
                        value: patient.occupation
                    )
                }

                if !patient.educationLevel.isEmpty {
                    DataRowView(
                        icon: "graduationcap",
                        title: "Nivel Académico",
                        value: patient.educationLevel.capitalized
                    )
                }

                if !patient.maritalStatus.isEmpty {
                    DataRowView(
                        icon: "heart",
                        title: "Estado Civil",
                        value: patient.maritalStatus.capitalized
                    )
                }
            }
        }
    }
}

private struct MedicalCoverageCard: View {
    let patient: Patient

    var body: some View {
        CardShell(title: "Cobertura Médica", systemImage: "cross.case") {
            VStack(spacing: 12) {
                if !patient.healthInsurance.isEmpty {
                    DataRowView(
                        icon: "cross.case.fill",
                        title: "Obra Social",
                        value: patient.healthInsurance
                    )
                }

                if !patient.insuranceMemberNumber.isEmpty {
                    DataRowView(
                        icon: "number",
                        title: "Nº Afiliado",
                        value: patient.insuranceMemberNumber
                    )
                }

                if !patient.insurancePlan.isEmpty {
                    DataRowView(
                        icon: "doc.text",
                        title: "Plan",
                        value: patient.insurancePlan
                    )
                }
            }
        }
    }
}

private struct ContactCard: View {
    let patient: Patient
    let emergencyContactSummary: String

    var body: some View {
        CardShell(title: "Contacto", systemImage: "person.crop.circle.badge.checkmark") {
            VStack(spacing: 12) {
                if !patient.email.isEmpty {
                    DataRowView(icon: "envelope", title: "Email", value: patient.email)
                }

                if !patient.phoneNumber.isEmpty {
                    DataRowView(icon: "phone", title: "Teléfono", value: patient.phoneNumber)
                }

                if !patient.address.isEmpty {
                    DataRowView(icon: "house", title: "Dirección", value: patient.address)
                }

                if !patient.emergencyContactName.isEmpty {
                    DataRowView(icon: "exclamationmark.triangle", title: "Emergencia", value: emergencyContactSummary)
                }
            }
        }
    }
}

private struct DiagnosesCard: View {
    let patient: Patient
    let diagnoses: [Diagnosis]
    let activeDiagnosesAsDTO: [ICD11SearchResult]
    let onAddDiagnosis: (ICD11SearchResult) -> Void
    let onRemoveDiagnosis: (Diagnosis) -> Void

    var body: some View {
        CardShell(title: "Diagnósticos Vigentes", systemImage: "stethoscope") {
            VStack(spacing: 10) {
                if diagnoses.isEmpty {
                    Text("Sin diagnósticos vigentes")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(diagnoses) { diagnosis in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(diagnosisTitle(for: diagnosis))
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if !diagnosis.icdCode.isEmpty {
                                    Text(diagnosis.icdCode)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.regularMaterial, in: Capsule())
                                }
                            }

                            Button(role: .destructive) {
                                onRemoveDiagnosis(diagnosis)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                NavigationLink {
                    ICD11SearchView(
                        alreadySelected: activeDiagnosesAsDTO,
                        onSelect: { result in
                            onAddDiagnosis(result)
                        }
                    )
                } label: {
                    Label("Agregar Diagnóstico", systemImage: "plus.circle")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func diagnosisTitle(for diagnosis: Diagnosis) -> String {
        diagnosis.icdTitleEs.isEmpty ? diagnosis.icdTitle : diagnosis.icdTitleEs
    }
}

private struct MedicalHistoryCard: View {
    let patient: Patient
    let professional: Professional

    var body: some View {
        CardShell(title: "Historia Clínica", systemImage: "heart.text.clipboard") {
            NavigationLink {
                PatientMedicalHistoryView(patient: patient, professional: professional)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.clipboard")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.accent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ver Historia Clínica")
                            .font(.body)
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var summary: String {
        var parts: [String] = []

        if !patient.medicalRecordNumber.isEmpty {
            parts.append(patient.medicalRecordNumber)
        }

        if let bmi = patient.bmi {
            parts.append("IMC \(String(format: "%.1f", bmi))")
        }

        if !patient.currentMedication.isEmpty {
            parts.append(patient.currentMedication)
        }

        return parts.isEmpty ? "Sin resumen clínico disponible" : parts.joined(separator: " · ")
    }
}

private struct SessionsCard: View {
    let patient: Patient
    let professional: Professional
    let onCreateSession: () -> Void

    private var sortedSessions: [Session] {
        (patient.sessions ?? []).sorted { $0.sessionDate > $1.sessionDate }
    }

    var body: some View {
        CardShell(title: "Sesiones", systemImage: "clock.arrow.circlepath") {
            VStack(spacing: 10) {
                if sortedSessions.isEmpty {
                    Text("Sin sesiones. Creá la primera sesión para este paciente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(sortedSessions) { session in
                        NavigationLink {
                            SessionDetailView(
                                session: session,
                                patient: patient,
                                professional: professional
                            )
                        } label: {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    onCreateSession()
                } label: {
                    Label("Nueva Sesión", systemImage: "plus.circle")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
        }
    }
}

private struct AuditInfoCard: View {
    let patient: Patient

    var body: some View {
        CardShell(title: "Información", systemImage: "info.circle") {
            VStack(spacing: 12) {
                DataRowView(
                    icon: "calendar.badge.clock",
                    title: "Creado",
                    value: patient.createdAt.esShortDate()
                )

                DataRowView(
                    icon: "pencil.and.outline",
                    title: "Modificado",
                    value: patient.updatedAt.esShortDateTime()
                )

                if !patient.isActive, let deletedAt = patient.deletedAt {
                    DataRowView(
                        icon: "person.crop.circle.badge.xmark",
                        title: "Fecha de baja",
                        value: deletedAt.esShortDateTime(),
                        valueStyle: .red
                    )
                }
            }
        }
    }
}

private struct PatientActionsCard: View {
    let isActive: Bool
    let onDeactivate: () -> Void
    let onRestore: () -> Void

    var body: some View {
        CardShell(title: "Acciones", systemImage: "slider.horizontal.3") {
            Group {
                if isActive {
                    Button(role: .destructive) {
                        onDeactivate()
                    } label: {
                        Label("Dar de Baja", systemImage: "person.crop.circle.badge.xmark")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Button {
                        onRestore()
                    } label: {
                        Label("Restaurar Paciente", systemImage: "arrow.counterclockwise")
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Components

private struct DataRowView: View {
    let icon: String
    let title: String
    let value: String
    var valueStyle: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(valueStyle)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct CardShell<Content: View>: View {

    enum Hierarchy {
        case primary
        case secondary
    }

    var title: String? = nil
    var systemImage: String? = nil
    var hierarchy: Hierarchy = .secondary
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: hierarchy == .primary ? 20 : 18, style: .continuous)
    }

    var body: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                if let title {
                    Label {
                        Text(title)
                            .font(.title3.bold())
                    } icon: {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                hierarchy == .primary ? .regularMaterial : .thinMaterial,
                in: shape
            )
        }
        .glassEffect(hierarchy == .primary ? .regular : .thin, in: .container)
        .clipShape(shape)
        .shadow(
            color: .black.opacity(hierarchy == .primary ? 0.10 : 0.08),
            radius: hierarchy == .primary ? 10 : 8,
            y: hierarchy == .primary ? 4 : 2
        )
    }
}

private struct SessionRowView: View {

    let session: Session

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.sessionDate.esShortDateTime())
                    .font(.body)

                if !session.chiefComplaint.isEmpty {
                    Text(session.chiefComplaint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let diagnoses = session.diagnoses, !diagnoses.isEmpty {
                    Text(
                        diagnoses
                            .compactMap { $0.icdCode.isEmpty ? nil : $0.icdCode }
                            .joined(separator: ", ")
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            SessionTypeBadge(
                label: sessionTypeLabel,
                systemImage: sessionTypeIcon,
                tint: sessionTypeTint
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

private struct SessionTypeBadge: View {
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
            Text(label)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }
}

private struct PDFExportShareView: View {

    @Environment(\.dismiss) private var dismiss

    let fileURL: URL
    let patientName: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)

                Text("PDF generado")
                    .font(.title3.bold())

                Text("Historia clínica de \(patientName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(fileURL.lastPathComponent)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ShareLink(
                    item: fileURL,
                    preview: SharePreview("Historia clínica de \(patientName)")
                ) {
                    Label("Compartir PDF", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
            .navigationTitle("Exportación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let professional = Professional(
        fullName: "Dr. Test",
        licenseNumber: "MN 999",
        specialty: "Psicología"
    )
    let patient = Patient(
        firstName: "Ana",
        lastName: "García",
        email: "ana@example.com",
        phoneNumber: "+54 11 1234-5678",
        professional: professional
    )

    NavigationStack {
        PatientDetailView(patient: patient, professional: professional)
    }
    .modelContainer(
        for: [
            Professional.self,
            Patient.self,
            Session.self,
            Diagnosis.self,
            Attachment.self,
            PriorTreatment.self,
            Hospitalization.self,
            AnthropometricRecord.self,
        ],
        inMemory: true
    )
}
