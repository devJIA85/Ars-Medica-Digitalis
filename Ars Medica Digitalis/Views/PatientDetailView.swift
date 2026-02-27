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

                ClinicalSummaryView(patient: patient)

                PersonalDataCard(patient: patient)

                MedicalHistoryCard(patient: patient, professional: professional)

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
            .backgroundExtensionEffect()
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
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
        (patient.activeDiagnoses ?? []).map(\.asSearchResult)
    }

    private func addActiveDiagnosis(_ result: ICD11SearchResult) {
        let existing = patient.activeDiagnoses ?? []
        guard !existing.contains(where: { $0.icdURI == result.id }) else { return }

        let diagnosis = Diagnosis(from: result, patient: patient)
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
        CardContainer(style: .elevated) {
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
                    // Próxima cita como señal contextual de actividad clínica inmediata
                    if let next = nextAppointmentDate {
                        Label("Próxima: \(next.esDayMonthAbbrev())", systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

    private var nextAppointmentDate: Date? {
        let today = Calendar.current.startOfDay(for: Date())
        return (patient.sessions ?? [])
            .filter { $0.sessionStatusValue == .programada && $0.sessionDate >= today }
            .map(\.sessionDate)
            .min()
    }
}

// MARK: - Resumen Clínico

private struct ClinicalSummaryView: View {
    let patient: Patient

    var body: some View {
        CardContainer(style: .flat) {
            HStack(spacing: 0) {
                clinicalStatChip(
                value: "\(patient.activeDiagnoses?.count ?? 0)",
                label: "Dx activos",
                icon: "stethoscope",
                accent: .blue
                )

                Divider()
                    .padding(.vertical, 8)

                clinicalStatChip(
                value: "\(medicationCount)",
                label: "Medicación",
                icon: "pills.fill",
                accent: .purple
                )

                Divider()
                    .padding(.vertical, 8)

                clinicalStatChip(
                value: bmiDisplayValue,
                label: "IMC",
                icon: "scalemass.fill",
                accent: bmiColor
                )
            }
        }
    }

    private func clinicalStatChip(value: String, label: String, icon: String, accent: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Label(label, systemImage: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .labelStyle(.titleAndIcon)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    // Contabiliza medicamentos estructurados del vademécum; si no hay,
    // detecta si existe texto libre como indicador de al menos 1 medicamento.
    private var medicationCount: Int {
        let structured = patient.currentMedications?.count ?? 0
        if structured == 0 && !patient.currentMedication.isEmpty { return 1 }
        return structured
    }

    private var bmiDisplayValue: String {
        guard let bmi = patient.bmi else { return "–" }
        return String(format: "%.1f", bmi)
    }

    private var bmiColor: Color {
        guard let bmi = patient.bmi, let cat = BMICategory(bmi: bmi) else { return .secondary }
        return cat.color
    }
}

// MARK: - Cards

private struct PersonalDataCard: View {
    let patient: Patient

    @State private var isExpanded: Bool = false

    var body: some View {
        CardContainer(style: .flat) {
            DisclosureGroup(isExpanded: $isExpanded) {
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

                // Subsección de cobertura: agrupa datos de obra social junto
                // con los datos personales para reducir tarjetas independientes
                if hasCoverageData {
                    Divider()
                        .padding(.vertical, 4)
                    Text("Cobertura Médica")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !patient.healthInsurance.isEmpty {
                        DataRowView(icon: "cross.case.fill", title: "Obra Social", value: patient.healthInsurance)
                    }
                    if !patient.insuranceMemberNumber.isEmpty {
                        DataRowView(icon: "number", title: "Nº Afiliado", value: patient.insuranceMemberNumber)
                    }
                    if !patient.insurancePlan.isEmpty {
                        DataRowView(icon: "doc.text", title: "Plan", value: patient.insurancePlan)
                    }
                }
            }
            .padding(.top, AppSpacing.sm)
        } label: {
            Label("Datos Personales", systemImage: "person.text.rectangle")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        }
    }

    private var hasCoverageData: Bool {
        !patient.healthInsurance.isEmpty
        || !patient.insuranceMemberNumber.isEmpty
        || !patient.insurancePlan.isEmpty
    }
}

private struct ContactCard: View {
    let patient: Patient
    let emergencyContactSummary: String

    var body: some View {
        CardContainer(title: "Contacto", systemImage: "person.crop.circle.badge.checkmark") {
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let patient: Patient
    let diagnoses: [Diagnosis]
    let activeDiagnosesAsDTO: [ICD11SearchResult]
    let onAddDiagnosis: (ICD11SearchResult) -> Void
    let onRemoveDiagnosis: (Diagnosis) -> Void

    // Diagnósticos vigentes arrancan expandidos por ser la sección más consultada
    @State private var isExpanded: Bool = true
    @State private var chapterByURI: [String: String] = [:]

    var body: some View {
        CardContainer(style: .flat) {
            DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 10) {
                if diagnoses.isEmpty {
                    Text("Sin diagnósticos vigentes")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(diagnoses) { diagnosis in
                        let chapter = chapterCode(for: diagnosis)
                        let accent = chapterColor(for: chapter)

                        HStack(alignment: .top, spacing: 12) {
                            Rectangle()
                                .fill(accent.opacity(0.85))
                                .frame(width: 4)
                                .clipShape(Capsule())

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(diagnosisTitle(for: diagnosis))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(titleColor(for: chapter))
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Button(role: .destructive) {
                                        onRemoveDiagnosis(diagnosis)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 8) {
                                    diagnosisMetaPill(
                                        text: diagnosisTypeLabel(for: diagnosis),
                                        icon: "stethoscope"
                                    )

                                    diagnosisMetaPill(
                                        text: diagnosis.diagnosedAt.esShortDateAbbrev(),
                                        icon: "calendar"
                                    )
                                }

                                if !diagnosis.clinicalNotes.trimmed.isEmpty {
                                    Text(diagnosis.clinicalNotes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(accent.opacity(0.16), lineWidth: 1)
                        )
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
            .padding(.top, AppSpacing.sm)
        } label: {
            Label("Diagnósticos Vigentes", systemImage: "stethoscope")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        }
        .task(id: diagnosesChapterCacheKey) {
            refreshChapterCache()
        }
    }

    private func diagnosisTitle(for diagnosis: Diagnosis) -> String {
        diagnosis.displayTitle
    }

    @ViewBuilder
    private func diagnosisMetaPill(text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
    }

    private func diagnosisTypeLabel(for diagnosis: Diagnosis) -> String {
        switch diagnosis.diagnosisType.lowercased() {
        case "principal":
            return "Principal"
        case "secundario":
            return "Secundario"
        case "diferencial":
            return "Diferencial"
        default:
            return diagnosis.diagnosisType.capitalized
        }
    }

    private var diagnosesChapterCacheKey: String {
        diagnoses
            .map(\.icdURI)
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "|")
    }

    private func refreshChapterCache() {
        let uris = Set(diagnoses.map(\.icdURI).filter { !$0.isEmpty })
        guard !uris.isEmpty else {
            chapterByURI = [:]
            return
        }

        let predicate = #Predicate<ICD11Entry> { entry in
            uris.contains(entry.uri)
        }
        let descriptor = FetchDescriptor<ICD11Entry>(predicate: predicate)
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        chapterByURI = Dictionary(uniqueKeysWithValues: entries.map { ($0.uri, $0.chapterCode) })
    }

    private func chapterCode(for diagnosis: Diagnosis) -> String? {
        let chapter = chapterByURI[diagnosis.icdURI] ?? ""
        return chapter.isEmpty ? nil : chapter
    }

    private func chapterColor(for chapter: String?) -> Color {
        guard let chapter, !chapter.isEmpty else { return .blue }

        let palette: [Color] = [.blue, .teal, .green, .mint, .indigo, .cyan, .orange, .pink]
        let hash = chapter.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            partialResult += Int(scalar.value)
        }
        return palette[hash % palette.count]
    }

    private func titleColor(for chapter: String?) -> Color {
        guard let chapter, !chapter.isEmpty else { return .primary }
        let base = chapterColor(for: chapter)
        return base.opacity(colorScheme == .dark ? 0.95 : 0.9)
    }
}

private struct MedicalHistoryCard: View {
    let patient: Patient
    let professional: Professional

    var body: some View {
        NavigationLink {
            PatientMedicalHistoryView(patient: patient, professional: professional)
        } label: {
            CardContainer(style: .flat) {
                HStack(spacing: 12) {
                    Label("Historia Clínica", systemImage: "heart.text.clipboard")
                        .font(.headline)
                        .foregroundStyle(.tint)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .buttonStyle(.plain)
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
        CardContainer(style: .flat) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Label("Sesiones", systemImage: "clock.arrow.circlepath")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    Button {
                        onCreateSession()
                    } label: {
                        Label("Nueva Sesión", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Nueva Sesión")
                }

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
            }
        }
    }
}

private struct AuditInfoCard: View {
    let patient: Patient

    var body: some View {
        CardContainer(style: .flat) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Información", systemImage: "info.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                DataRowView(
                    icon: "calendar.badge.clock",
                    title: "Creado",
                    value: patient.createdAt.esShortDate(),
                    compact: true
                )

                DataRowView(
                    icon: "pencil.and.outline",
                    title: "Modificado",
                    value: patient.updatedAt.esShortDateTime(),
                    compact: true
                )

                if !patient.isActive, let deletedAt = patient.deletedAt {
                    DataRowView(
                        icon: "person.crop.circle.badge.xmark",
                        title: "Fecha de baja",
                        value: deletedAt.esShortDateTime(),
                        valueStyle: .red,
                        compact: true
                    )
                }
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
        CardContainer(title: "Acciones", systemImage: "slider.horizontal.3") {
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
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(compact ? .caption : .body)
                .frame(width: compact ? 18 : 24)

            VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                Text(title)
                    .font(compact ? .caption2 : .footnote)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(compact ? .footnote : .body)
                    .foregroundStyle(valueStyle)
            }

            Spacer(minLength: 0)
        }
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

                // compactMap implica opcionales; icdCode es String no opcional.
                // filter + map nombra correctamente la operación: se filtra por contenido
                // vacío, no se desenvuelve ningún opcional.
                let codes = (session.diagnoses ?? [])
                    .map(\.displayTitle)
                    .filter { !$0.isEmpty }
                if !codes.isEmpty {
                    let preview = codes.prefix(2).joined(separator: " · ")
                    let extra = codes.count > 2 ? " +\(codes.count - 2)" : ""
                    Text("Dx: \(preview)\(extra)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            StatusBadge(
                label: sessionTypeLabel,
                variant: .custom(sessionTypeTint),
                systemImage: sessionTypeIcon
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var sessionTypeLabel: String {
        sessionTypeMapping?.abbreviatedLabel ?? session.sessionType
    }

    private var sessionTypeIcon: String {
        sessionTypeMapping?.icon ?? "questionmark"
    }

    private var sessionTypeTint: Color {
        sessionTypeMapping?.tint ?? .secondary
    }

    private var sessionTypeMapping: SessionTypeMapping? {
        SessionTypeMapping(sessionTypeRawValue: session.sessionType)
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
    .modelContainer(ModelContainer.preview)
}
