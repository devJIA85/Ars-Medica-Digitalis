//
//  PatientDetailView.swift
//  Ars Medica Digitalis
//
//  Overview clínico del paciente con arquitectura Health-centric:
//  diagnósticos activos como protagonista, timeline de sesiones,
//  y contexto administrativo plegado al final.
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
    @State private var showingDebtSettlement: Bool = false
    @State private var didAppearDiagnoses: Bool = false
    @State private var didAppearSessions: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionGap) {

                // 1. Avatar + próxima cita (sin card, sin nombre)
                PatientQuickInfo(patient: patient)

                // 2. Diagnósticos activos — card elevada Apple Health
                ActiveDiagnosesCard(
                    patient: patient,
                    diagnoses: sortedActiveDiagnoses,
                    activeDiagnosesAsDTO: activeDiagnosesAsDTO,
                    onAddDiagnosis: addActiveDiagnosis,
                    onRemoveDiagnosis: removeActiveDiagnosis,
                    onMarkAsPrimary: markDiagnosisAsPrimary
                )
                .opacity(didAppearDiagnoses ? 1 : 0)
                .scaleEffect(didAppearDiagnoses ? 1 : 0.97)
                .animation(.smooth(duration: 0.4), value: didAppearDiagnoses)

                // 3. Historia clínica — acceso rápido siempre visible
                MedicationCard(
                    patient: patient,
                    professional: professional,
                    count: activeMedicationCount
                )

                NavigationLink {
                    ScalesListView(
                        patientID: patient.id,
                        patientName: patient.fullName
                    )
                } label: {
                    CardContainer(style: .flat) {
                        HStack(spacing: AppSpacing.md) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "list.bullet.clipboard")
                                        .foregroundStyle(Color.accentColor)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Escalas clínicas")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text("BDI-II y próximas escalas psicométricas")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: AppSpacing.md)

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                if patient.hasOutstandingDebt {
                    PatientFinanceCard(
                        patient: patient,
                        onSettleDebt: { showingDebtSettlement = true }
                    )
                }

                // 4. Sesiones — timeline protagonista
                SessionsSection(
                    patient: patient,
                    onCreateSession: { showingNewSession = true }
                )
                .opacity(didAppearSessions ? 1 : 0)
                .offset(y: didAppearSessions ? 0 : 16)
                .animation(.smooth(duration: 0.4).delay(0.08), value: didAppearSessions)

                // 5. Contexto plegable — datos personales, HC, contacto, audit, acciones
                CollapsibleContextSection(
                    patient: patient,
                    professional: professional,
                    hasContactData: hasContactData,
                    emergencyContactSummary: emergencyContactSummary,
                    onDeactivate: { showingDeleteConfirmation = true },
                    onRestore: {
                        patient.deletedAt = nil
                        patient.updatedAt = Date()
                    }
                )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 18)
            .safeAreaPadding(.bottom, AppSpacing.lg)
            .backgroundExtensionEffect()
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .onAppear {
            guard !didAppearDiagnoses else { return }
            didAppearDiagnoses = true
            didAppearSessions = true
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PatientHeaderContent(patient: patient)
            }

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
                .buttonStyle(.glass)
                .accessibilityLabel("Exportar PDF")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Editar paciente")
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
        .sheet(isPresented: $showingDebtSettlement) {
            NavigationStack {
                PatientDebtSettlementView(
                    patient: patient,
                    context: modelContext,
                    showsCloseButton: true
                )
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

    // MARK: - Medicación

    private var activeMedicationCount: Int {
        let structured = patient.currentMedications?.count ?? 0
        if structured > 0 { return structured }
        return patient.currentMedication.trimmed.isEmpty ? 0 : 1
    }

    // MARK: - Diagnósticos vigentes

    /// Diagnósticos ordenados: principal primero, luego secundario/diferencial por fecha
    private var sortedActiveDiagnoses: [Diagnosis] {
        (patient.activeDiagnoses ?? []).sorted { a, b in
            let aIsPrimary = a.diagnosisType.lowercased() == "principal"
            let bIsPrimary = b.diagnosisType.lowercased() == "principal"
            if aIsPrimary != bIsPrimary { return aIsPrimary }
            return a.diagnosedAt > b.diagnosedAt
        }
    }

    private var activeDiagnosesAsDTO: [ICD11SearchResult] {
        (patient.activeDiagnoses ?? []).map(\.asSearchResult)
    }

    private func addActiveDiagnosis(_ result: ICD11SearchResult) {
        let existing = patient.activeDiagnoses ?? []
        guard !existing.contains(where: { $0.icdURI == result.id }) else { return }

        // Si no hay diagnósticos, el primero es principal; sino secundario
        let type = existing.isEmpty ? "principal" : "secundario"
        let diagnosis = Diagnosis(from: result, patient: patient)
        diagnosis.diagnosisType = type
        modelContext.insert(diagnosis)
        patient.updatedAt = Date()
    }

    private func removeActiveDiagnosis(_ diagnosis: Diagnosis) {
        modelContext.delete(diagnosis)
        patient.updatedAt = Date()
    }

    /// Marca un diagnóstico como principal y degrada el anterior principal a secundario
    private func markDiagnosisAsPrimary(_ diagnosis: Diagnosis) {
        for d in patient.activeDiagnoses ?? [] where d.diagnosisType.lowercased() == "principal" {
            d.diagnosisType = "secundario"
        }
        diagnosis.diagnosisType = "principal"
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

// MARK: - Finanzas

private struct PatientFinanceCard: View {
    let patient: Patient
    let onSettleDebt: () -> Void

    var body: some View {
        CardContainer(style: .flat) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .center) {
                    Text(L10n.tr("Finanzas"))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    StatusBadge(
                        label: L10n.tr("patient.list.badge.debt"),
                        variant: .warning,
                        systemImage: "exclamationmark.circle"
                    )
                }

                ForEach(patient.debtByCurrency) { summary in
                    LabeledContent(summary.currencyCode) {
                        Text(summary.debt.formattedCurrency(code: summary.currencyCode))
                            .fontWeight(.semibold)
                    }
                }

                Text(L10n.tr("patient.debt.card.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(action: onSettleDebt) {
                    Text(L10n.tr("patient.debt.card.action"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Header (toolbar principal)

private struct PatientHeaderContent: View {
    let patient: Patient

    var body: some View {
        VStack(spacing: 2) {
            Text(patient.fullName)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(patient.fullName), \(subtitle)")
    }

    private var subtitle: String {
        var parts = ["\(patient.age) años"]
        if let nextBirthday = patient.nextBirthday {
            parts.append("Cumple \(nextBirthday.esDayMonthAbbrev())")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Quick Info (avatar + próxima cita)

private struct PatientQuickInfo: View {
    let patient: Patient

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            PatientAvatarView(
                photoData: patient.photoData,
                firstName: patient.firstName,
                lastName: patient.lastName,
                genderHint: patient.gender.isEmpty ? patient.biologicalSex : patient.gender,
                clinicalStatus: patient.clinicalStatus,
                size: 56
            )
            .accessibilityHidden(true)

            // Reúne la próxima cita y la moneda asignada en el mismo bloque
            // para que el profesional vea de un vistazo agenda y contexto financiero.
            if nextAppointmentDate != nil || assignedCurrencyCode.isEmpty == false || patient.hasOutstandingDebt {
                HStack(spacing: AppSpacing.sm) {
                    if let next = nextAppointmentDate {
                        StatusBadge(
                            label: "Próxima: \(next.esDayMonthAbbrev())",
                            variant: .warning,
                            systemImage: "calendar.badge.clock"
                        )
                    }

                    if assignedCurrencyCode.isEmpty == false {
                        StatusBadge(
                            label: assignedCurrencyCode,
                            variant: .custom(.blue),
                            systemImage: "dollarsign.circle"
                        )
                    }

                    if patient.hasOutstandingDebt {
                        StatusBadge(
                            label: L10n.tr("patient.list.badge.debt"),
                            variant: .danger,
                            systemImage: "exclamationmark.circle"
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var nextAppointmentDate: Date? {
        let today = Calendar.current.startOfDay(for: Date())
        return (patient.sessions ?? [])
            .filter { $0.sessionStatusValue == .programada && $0.sessionDate >= today }
            .map(\.sessionDate)
            .min()
    }

    private var assignedCurrencyCode: String {
        patient.currencyCode.trimmed
    }

    private var accessibilityDescription: String {
        var parts = ["Estado clínico: \(patient.clinicalStatus)"]
        if let next = nextAppointmentDate {
            parts.append("Próxima cita: \(next.esDayMonthAbbrev())")
        }
        if assignedCurrencyCode.isEmpty == false {
            parts.append("Moneda asignada: \(assignedCurrencyCode)")
        }
        if patient.hasOutstandingDebt {
            parts.append("Con deuda pendiente")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Diagnósticos Activos (card Apple Health)

private struct ActiveDiagnosesCard: View {
    let patient: Patient
    let diagnoses: [Diagnosis]
    let activeDiagnosesAsDTO: [ICD11SearchResult]
    let onAddDiagnosis: (ICD11SearchResult) -> Void
    let onRemoveDiagnosis: (Diagnosis) -> Void
    let onMarkAsPrimary: (Diagnosis) -> Void

    var body: some View {
        if diagnoses.isEmpty {
            // Estado vacío: card con botón "Agregar diagnóstico"
            CardContainer(style: .elevated) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Diagnósticos Activos")
                        .font(.title3.bold())

                    Text("Sin diagnósticos activos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        ICD11SearchView(
                            alreadySelected: activeDiagnosesAsDTO,
                            onSelect: { result in onAddDiagnosis(result) }
                        )
                    } label: {
                        Label("Agregar diagnóstico", systemImage: "plus.circle")
                            .font(.body)
                    }
                    .padding(.top, AppSpacing.xs)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Diagnósticos activos. Sin diagnósticos activos.")
            .accessibilityHint("Toque para agregar un diagnóstico")
        } else {
            // Card con resumen de diagnósticos — tap navega a lista completa
            NavigationLink {
                ActiveDiagnosesListView(
                    patient: patient,
                    diagnoses: diagnoses,
                    activeDiagnosesAsDTO: activeDiagnosesAsDTO,
                    onAddDiagnosis: onAddDiagnosis,
                    onRemoveDiagnosis: onRemoveDiagnosis,
                    onMarkAsPrimary: onMarkAsPrimary
                )
            } label: {
                CardContainer(style: .elevated) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text("Diagnósticos Activos")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }

                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Diagnóstico principal visible
                        if let primary = diagnoses.first {
                            Text(primary.displayTitle)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        // Adicionales
                        if diagnoses.count > 1 {
                            Text("+\(diagnoses.count - 1) adicionales")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Diagnósticos activos, \(subtitleText)")
            .accessibilityHint("Abre la lista completa de diagnósticos")
        }
    }

    private var subtitleText: String {
        let count = diagnoses.count
        return "\(count) activo\(count == 1 ? "" : "s")"
    }
}

// MARK: - Lista completa de diagnósticos activos

private struct ActiveDiagnosesListView: View {
    let patient: Patient
    let diagnoses: [Diagnosis]
    let activeDiagnosesAsDTO: [ICD11SearchResult]
    let onAddDiagnosis: (ICD11SearchResult) -> Void
    let onRemoveDiagnosis: (Diagnosis) -> Void
    let onMarkAsPrimary: (Diagnosis) -> Void

    @State private var diagnosisPendingRemoval: Diagnosis? = nil

    var body: some View {
        List {
            ForEach(diagnoses) { diagnosis in
                diagnosisRow(for: diagnosis)
                    .swipeActions(edge: .leading) {
                        if !isPrimary(diagnosis) {
                            Button {
                                withAnimation(.smooth(duration: 0.24)) {
                                    onMarkAsPrimary(diagnosis)
                                }
                            } label: {
                                Label("Principal", systemImage: "star.fill")
                            }
                            .tint(.orange)
                        }
                    }
            }

            NavigationLink {
                ICD11SearchView(
                    alreadySelected: activeDiagnosesAsDTO,
                    onSelect: { result in onAddDiagnosis(result) }
                )
            } label: {
                Label("Agregar Diagnóstico", systemImage: "plus.circle")
                    .font(.body)
                    .foregroundStyle(.tint)
            }
        }
        .navigationTitle("Diagnósticos Activos")
        .confirmationDialog(
            "Quitar diagnóstico",
            isPresented: Binding(
                get: { diagnosisPendingRemoval != nil },
                set: { if !$0 { diagnosisPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                guard let diagnosisPendingRemoval else { return }
                withAnimation(.smooth(duration: 0.24)) {
                    onRemoveDiagnosis(diagnosisPendingRemoval)
                }
                self.diagnosisPendingRemoval = nil
            }
            Button("Cancelar", role: .cancel) {
                diagnosisPendingRemoval = nil
            }
        } message: {
            Text("Se quitará de diagnósticos vigentes.")
        }
    }

    private func diagnosisRow(for diagnosis: Diagnosis) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    // Indicador visual de diagnóstico principal
                    if isPrimary(diagnosis) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }

                    Text(diagnosis.displayTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                HStack(spacing: AppSpacing.sm) {
                    Text(diagnosisTypeLabel(for: diagnosis))
                        .font(.caption)
                        .foregroundStyle(isPrimary(diagnosis) ? .orange : .secondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(diagnosis.diagnosedAt.esShortDateAbbrev())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !diagnosis.clinicalNotes.trimmed.isEmpty {
                    Text(diagnosis.clinicalNotes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Button {
                diagnosisPendingRemoval = diagnosis
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Eliminar diagnóstico \(diagnosis.displayTitle)")
        }
        .contentShape(Rectangle())
    }

    private func isPrimary(_ diagnosis: Diagnosis) -> Bool {
        diagnosis.diagnosisType.lowercased() == "principal"
    }

    private func diagnosisTypeLabel(for diagnosis: Diagnosis) -> String {
        switch diagnosis.diagnosisType.lowercased() {
        case "principal": return "Principal"
        case "secundario": return "Secundario"
        case "diferencial": return "Diferencial"
        default: return diagnosis.diagnosisType.capitalized
        }
    }
}

// MARK: - Medicación (condicional)

private struct MedicationCard: View {
    let patient: Patient
    let professional: Professional
    let count: Int

    private var summaryText: String {
        count > 0 ? "\(count) med. activa\(count == 1 ? "" : "s")" : "Sin med. activa"
    }

    private var accessibilitySummary: String {
        count > 0
            ? "\(count) medicación activa\(count == 1 ? "" : "s")"
            : "sin medicación activa"
    }

    var body: some View {
        NavigationLink {
            PatientMedicalHistoryView(patient: patient, professional: professional)
        } label: {
            CardContainer(style: .flat) {
                HStack {
                    Label("Historia Clínica", systemImage: "heart.text.clipboard")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Historia clínica, \(accessibilitySummary)")
        .accessibilityHint("Abre la historia clínica")
    }
}

// MARK: - Sesiones (timeline protagonista)

private struct SessionsSection: View {
    @Environment(\.modelContext) private var modelContext

    let patient: Patient
    let onCreateSession: () -> Void

    @State private var sessionViewModel = SessionViewModel()
    @State private var pendingCompletion: PendingPatientSessionCompletion?
    @State private var completionErrorMessage: String?

    private static let visibleLimit = 3

    private var sortedSessions: [Session] {
        (patient.sessions ?? []).sorted { $0.sessionDate > $1.sessionDate }
    }

    private var visibleSessions: [Session] {
        Array(sortedSessions.prefix(Self.visibleLimit))
    }

    var body: some View {
        CardContainer(style: .flat) {
            VStack(spacing: AppSpacing.md) {
                // Header: título + botón "+"
                HStack {
                    Text("Sesiones")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onCreateSession()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.tint, in: Circle())
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Nueva sesión")
                }

                if sortedSessions.isEmpty {
                    Text("Sin sesiones. Creá la primera sesión para este paciente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visibleSessions.enumerated()), id: \.element.id) { index, session in
                            sessionListItem(
                                for: session,
                                isFirst: index == 0,
                                isLast: index == visibleSessions.count - 1
                            )

                            if index < visibleSessions.count - 1 {
                                Divider()
                                    .padding(.leading, 24)
                            }
                        }
                    }

                    // Footer: "Ver historial completo"
                    if sortedSessions.count > Self.visibleLimit {
                        NavigationLink {
                            SessionHistoryListView(patient: patient)
                        } label: {
                            Text("Ver historial completo")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.tint)
                                .frame(maxWidth: .infinity)
                                .padding(.top, AppSpacing.xs)
                        }
                    }
                }
            }
        }
        .sheet(item: $pendingCompletion) { item in
            PaymentFlowView(draft: item.completionDraft, onCancel: {}) { paymentIntent in
                try sessionViewModel.completeSession(item.session, in: modelContext, paymentIntent: paymentIntent)
            }
        }
        .alert("No se pudo completar la sesión", isPresented: completionErrorBinding) {
            Button("Aceptar", role: .cancel) {
                completionErrorMessage = nil
            }
        } message: {
            Text(completionErrorMessage ?? "Ocurrió un error al registrar el cierre.")
        }
    }

    @ViewBuilder
    private func sessionListItem(for session: Session, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            NavigationLink {
                SessionFormView(patient: patient, session: session)
            } label: {
                SessionRowView(
                    session: session,
                    isFirst: isFirst,
                    isLast: isLast
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if canCompleteSession(session) {
                Button {
                    openCompletionFlow(for: session)
                } label: {
                    Text("Completar")
                        .font(.footnote.weight(.semibold))
                        .frame(minWidth: 104)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 18)
                .accessibilityLabel(completionButtonLabel(for: session))
                .accessibilityHint("Abre el flujo de cierre y cobro de la sesión")
            }
        }
    }

    private func canCompleteSession(_ session: Session) -> Bool {
        session.sessionStatusValue == .programada
    }

    private func completionButtonLabel(for session: Session) -> String {
        session.isCourtesy ? "Completar cortesía" : "Completar sesión"
    }

    @MainActor
    private func openCompletionFlow(for session: Session) {
        pendingCompletion = PendingPatientSessionCompletion(
            session: session,
            completionDraft: sessionViewModel.preparePaymentFlow(for: session)
        )
    }

    private var completionErrorBinding: Binding<Bool> {
        Binding(
            get: { completionErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    completionErrorMessage = nil
                }
            }
        )
    }
}

// MARK: - Historial completo de sesiones

private struct SessionHistoryListView: View {
    let patient: Patient

    private var sortedSessions: [Session] {
        (patient.sessions ?? []).sorted { $0.sessionDate > $1.sessionDate }
    }

    var body: some View {
        List {
            ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                NavigationLink {
                    SessionFormView(patient: patient, session: session)
                } label: {
                    SessionRowView(
                        session: session,
                        isFirst: index == 0,
                        isLast: index == sortedSessions.count - 1
                    )
                }
            }
        }
        .navigationTitle("Historial de Sesiones")
    }
}

private struct PendingPatientSessionCompletion: Identifiable {
    let session: Session
    let completionDraft: CompletionDraft

    var id: UUID { completionDraft.sessionID }
}

// MARK: - Session Row

private struct SessionRowView: View {

    let session: Session
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineIndicator
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // Fecha (secondary)
                Text(session.sessionDate.esShortDateTime())
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Motivo / nota (primary, protagonista)
                Text(shortSummary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                HStack(spacing: AppSpacing.sm) {
                    // Chip tipo de sesión
                    if let mapping = sessionTypeMapping {
                        StatusBadge(
                            label: mapping.abbreviatedLabel,
                            variant: .custom(mapping.tint),
                            systemImage: mapping.icon
                        )
                    }

                    if hasAINarrative {
                        StatusBadge(
                            label: "IA",
                            variant: .custom(.purple),
                            systemImage: "sparkles"
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var timelineIndicator: some View {
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
                .frame(minHeight: isLast ? 0 : 26, maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 12)
    }

    private var sessionTypeMapping: SessionTypeMapping? {
        SessionTypeMapping(sessionTypeRawValue: session.sessionType)
    }

    private var shortSummary: String {
        let complaint = session.chiefComplaint.trimmed
        if !complaint.isEmpty { return complaint }

        let notes = session.notes.trimmed
        if !notes.isEmpty { return notes }

        let plan = session.treatmentPlan.trimmed
        if !plan.isEmpty { return plan }

        return "Sin resumen clínico"
    }

    private var hasAINarrative: Bool {
        let text = "\(session.notes)\n\(session.treatmentPlan)"
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.contains("[ia]")
            || text.contains("narrativa ia")
            || text.contains("generado por ia")
            || text.contains("ai:")
    }

    private var accessibilityDescription: String {
        let date = session.sessionDate.esShortDateTime()
        let type = sessionTypeMapping?.abbreviatedLabel ?? session.sessionType
        return "\(date), \(type), \(shortSummary)"
    }
}

// MARK: - Contexto plegable

private struct CollapsibleContextSection: View {
    let patient: Patient
    let professional: Professional
    let hasContactData: Bool
    let emergencyContactSummary: String
    let onDeactivate: () -> Void
    let onRestore: () -> Void

    private var expansionKey: String {
        "patient.detail.\(patient.id.uuidString).section.context"
    }

    var body: some View {
        CardContainer(style: .flat) {
            PersistedDisclosureGroup(key: expansionKey) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {

                    // — Datos personales
                    sectionHeader("Datos Personales")
                    personalDataContent

                    if hasCoverageData {
                        sectionHeader("Cobertura Médica")
                        coverageContent
                    }

                    Divider()

                    // — Historia clínica
                    medicalHistoryLink

                    Divider()

                    // — Contacto (condicional)
                    if hasContactData {
                        sectionHeader("Contacto")
                        contactContent

                        Divider()
                    }

                    // — Registro
                    sectionHeader("Registro")
                    auditContent

                    Divider()

                    // — Acciones
                    actionsContent
                }
                .padding(.top, AppSpacing.sm)
            } label: {
                Label("Información del Paciente", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Sub-secciones

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var personalDataContent: some View {
        VStack(spacing: 12) {
            DataRowView(
                icon: "calendar",
                title: "Nacimiento",
                value: patient.dateOfBirth.esShortDateAbbrev()
            )

            if !patient.biologicalSex.isEmpty {
                DataRowView(icon: "figure.stand", title: "Sexo Biológico", value: patient.biologicalSex.capitalized)
            }

            if !patient.gender.isEmpty {
                DataRowView(icon: "person.crop.square", title: "Género", value: patient.gender.capitalized)
            }

            if !patient.nationalId.isEmpty {
                DataRowView(icon: "person.text.rectangle", title: "Documento", value: patient.nationalId)
            }

            if !patient.nationality.isEmpty {
                DataRowView(icon: "globe", title: "Nacionalidad", value: patient.nationality)
            }

            if !patient.residenceCountry.isEmpty {
                DataRowView(icon: "mappin.and.ellipse", title: "País de Residencia", value: patient.residenceCountry)
            }

            if !patient.occupation.isEmpty {
                DataRowView(icon: "briefcase", title: "Ocupación", value: patient.occupation)
            }

            if !patient.educationLevel.isEmpty {
                DataRowView(icon: "graduationcap", title: "Nivel Académico", value: patient.educationLevel.capitalized)
            }

            if !patient.maritalStatus.isEmpty {
                DataRowView(icon: "heart", title: "Estado Civil", value: patient.maritalStatus.capitalized)
            }
        }
    }

    @ViewBuilder
    private var coverageContent: some View {
        VStack(spacing: 12) {
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

    private var medicalHistoryLink: some View {
        NavigationLink {
            PatientMedicalHistoryView(patient: patient, professional: professional)
        } label: {
            HStack {
                Label("Historia Clínica", systemImage: "heart.text.clipboard")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contactContent: some View {
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

    @ViewBuilder
    private var auditContent: some View {
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

    @ViewBuilder
    private var actionsContent: some View {
        if patient.isActive {
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

    private var hasCoverageData: Bool {
        !patient.healthInsurance.isEmpty
        || !patient.insuranceMemberNumber.isEmpty
        || !patient.insurancePlan.isEmpty
    }
}

// MARK: - Componentes reutilizables

private struct PersistedDisclosureGroup<Label: View, Content: View>: View {
    private let key: String
    private let content: Content
    private let label: Label
    @State private var isExpanded: Bool

    init(
        key: String,
        defaultExpanded: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.key = key
        self.content = content()
        self.label = label()

        let persisted = UserDefaults.standard.object(forKey: key) as? Bool
        _isExpanded = State(initialValue: persisted ?? defaultExpanded)
    }

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { newValue in
                    isExpanded = newValue
                    UserDefaults.standard.set(newValue, forKey: key)
                }
            )
        ) {
            content
        } label: {
            label
        }
    }
}

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
                .accessibilityHidden(true)

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

// MARK: - PDF Export

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
