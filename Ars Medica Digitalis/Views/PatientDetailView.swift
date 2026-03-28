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
import OSLog

struct PatientDetailView: View {

    private let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "PatientDetailView")

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.auditService) private var auditService
    // TODO: [Audit Trail] Inyectar currentActorID desde ContentView:
    // .environment(\.currentActorID, professional.id.uuidString)
    @Environment(\.currentActorID) private var currentActorID

    let patient: Patient
    let professional: Professional

    @State private var showingEdit: Bool = false
    @State private var showingNewSession: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var showingReactivateConfirmation: Bool = false
    @State private var isExportingPDF: Bool = false
    @State private var showingPDFShareSheet: Bool = false
    @State private var exportedPDFURL: URL? = nil
    @State private var exportErrorMessage: String? = nil
    @State private var showingDebtSettlement: Bool = false
    @State private var didAppearDiagnoses: Bool = false
    @State private var didAppearSessions: Bool = false

    var body: some View {
        ScrollView {
            GlassEffectContainer {
            VStack(spacing: AppSpacing.sectionGap) {

                // 1. Compact header — avatar + name + clinical status
                PatientQuickInfo(patient: patient)

                // Context badges — next appointment, currency, debt
                contextBadges

                // 2. Primary diagnosis — the most clinically important card
                ActiveDiagnosesCard(
                    patient: patient,
                    diagnoses: sortedActiveDiagnoses,
                    activeDiagnosesAsDTO: activeDiagnosesAsDTO,
                    onAddDiagnosis: addActiveDiagnosis,
                    onRemoveDiagnosis: removeActiveDiagnosis,
                    onMarkAsPrimary: markDiagnosisAsPrimary
                )
                .opacity(didAppearDiagnoses ? 1 : 0)
                .scaleEffect((didAppearDiagnoses || reduceMotion) ? 1 : 0.97)
                .animation(
                    reduceMotion ? .easeIn(duration: 0.15) : .smooth(duration: 0.4),
                    value: didAppearDiagnoses
                )

                // 3. Sessions — timeline protagonista: acción clínica primaria.
                // El padding(.top) adicional amplía el espacio visual por encima
                // de la sección dominante, separándola del diagnóstico (más ligero)
                // y haciendo visible la jerarquía sin cambiar el sectionGap global.
                SessionsSection(
                    patient: patient,
                    onCreateSession: { showingNewSession = true }
                )
                .padding(.top, AppSpacing.sm)
                .opacity(didAppearSessions ? 1 : 0)
                .offset(y: (didAppearSessions || reduceMotion) ? 0 : 16)
                .animation(
                    reduceMotion ? .easeIn(duration: 0.15) : .smooth(duration: 0.4).delay(0.08),
                    value: didAppearSessions
                )

                // 4 + 5. Cluster secundario: timeline + módulos clínicos agrupados
                // con spacing reducido (sm vs sectionGap) para distinguirlos
                // visualmente del bloque primario (diagnóstico + sesiones).
                // El agrupamiento perceptual comunica "esto es de segunda lectura".
                VStack(spacing: AppSpacing.sm) {
                    ClinicalActivityTimeline(patient: patient)

                    ClinicalModuleRow(
                        title: L10n.tr("patient.section.clinicalData.title"),
                        systemImage: "heart.text.clipboard",
                        detail: medicationDetail
                    ) {
                        PatientMedicalHistoryView(patient: patient, professional: professional)
                    }

                    ClinicalModuleRow(
                        title: "Escalas clínicas",
                        systemImage: "list.bullet.clipboard",
                        detail: scalesDetail
                    ) {
                        ScalesListView(
                            patientID: patient.id,
                            patientName: patient.fullName
                        )
                    }
                    .accessibilityIdentifier("patient.detail.scales")
                }

                // 6. Finanzas — contexto administrativo de apoyo, no interrumpe
                // el flujo clínico al aparecer después de los módulos clínicos.
                if patient.hasOutstandingDebt {
                    PatientFinanceCard(
                        patient: patient,
                        onSettleDebt: { showingDebtSettlement = true }
                    )
                }

                // Historial financiero centrado en sesiones: una fila = una sesión,
                // estado de cobro visible de inmediato sin cálculo mental.
                if !FinancialLedgerBuilder.availableCurrencies(for: patient).isEmpty {
                    PatientSessionFinancialListView(patient: patient)
                }

                // 7. Patient info — collapsible, reduced dividers
                CollapsibleContextSection(
                    patient: patient,
                    professional: professional,
                    hasContactData: hasContactData,
                    emergencyContactSummary: emergencyContactSummary,
                    onDeactivate: { showingDeleteConfirmation = true },
                    onRestore: { showingReactivateConfirmation = true }
                )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 18)
            } // GlassEffectContainer
            .backgroundExtensionEffect()
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .onAppear {
            guard !didAppearDiagnoses else { return }
            didAppearDiagnoses = true
            didAppearSessions = true
        }
        // El título nativo aparece en la barra solo cuando PatientQuickInfo
        // sale del viewport al hacer scroll, eliminando la duplicación permanente.
        .navigationTitle(patient.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Edición: acción primaria de contenido — trailing por convención iOS.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Editar paciente")
            }

            // Exportar PDF: acción secundaria de utilidad — dentro de un menú
            // para no saturar el espacio y mantener jerarquía visual.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportPatientPDF()
                    } label: {
                        Label("Exportar PDF", systemImage: "doc.richtext")
                    }
                    .disabled(isExportingPDF)

                    Divider()

                    if patient.isActive {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Desactivar paciente", systemImage: "person.crop.circle.badge.xmark")
                        }
                    } else {
                        Button {
                            showingReactivateConfirmation = true
                        } label: {
                            Label("Reactivar paciente", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                } label: {
                    if isExportingPDF {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Más acciones")
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
            isPresented: $exportErrorMessage.isPresent
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
                patient.softDelete()
                auditService.log(action: .softDelete, on: patient, in: modelContext, performedBy: currentActorID)
                do {
                    try modelContext.save()
                } catch {
                    logger.error("Patient softDelete save failed: \(error, privacy: .private)")
                }
            }
        } message: {
            Text(L10n.tr("patient.confirmation.deactivate.message"))
        }
        .confirmationDialog(
            "Reactivar paciente",
            isPresented: $showingReactivateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reactivar") {
                patient.restore()
                auditService.log(action: .restore, on: patient, in: modelContext, performedBy: currentActorID)
                do {
                    try modelContext.save()
                } catch {
                    logger.error("Patient restore save failed: \(error, privacy: .private)")
                }
            }
        } message: {
            Text("Este paciente volverá a estar activo y disponible en el sistema.")
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

    // MARK: - Context badges

    @ViewBuilder
    private var contextBadges: some View {
        // Próxima sesión ya está integrada en PatientQuickInfo.metadataLine —
        // aquí solo mostramos badges de estado financiero/administrativo.
        let currency = patient.currencyCode.trimmed
        let hasDebt = patient.hasOutstandingDebt

        if currency.isEmpty == false || hasDebt {
            HStack(spacing: AppSpacing.sm) {
                if currency.isEmpty == false {
                    StatusBadge(
                        label: currency,
                        variant: .custom(.blue),
                        systemImage: "dollarsign.circle"
                    )
                }

                if hasDebt {
                    StatusBadge(
                        label: L10n.tr("patient.list.badge.debt"),
                        variant: .danger,
                        systemImage: "exclamationmark.circle"
                    )
                }
            }
        }
    }

    // MARK: - Clinical module details

    private var medicationDetail: String {
        let count = activeMedicationCount
        return count > 0 ? "\(count) med. activa\(count == 1 ? "" : "s")" : "Sin med. activa"
    }

    private var scalesDetail: String {
        "BDI-II disponible"
    }

    // MARK: - Medicación

    private var activeMedicationCount: Int {
        let structured = patient.currentMedications.count
        if structured > 0 { return structured }
        return patient.currentMedication.trimmed.isEmpty ? 0 : 1
    }

    // MARK: - Diagnósticos vigentes

    /// Diagnósticos ordenados: principal primero, luego secundario/diferencial por fecha
    private var sortedActiveDiagnoses: [Diagnosis] {
        patient.activeDiagnoses.sorted { a, b in
            let aIsPrimary = a.diagnosisTypeValue.isPrimary
            let bIsPrimary = b.diagnosisTypeValue.isPrimary
            if aIsPrimary != bIsPrimary { return aIsPrimary }
            return a.diagnosedAt > b.diagnosedAt
        }
    }

    private var activeDiagnosesAsDTO: [ICD11SearchResult] {
        patient.activeDiagnoses.map(\.asSearchResult)
    }

    private func addActiveDiagnosis(_ result: ICD11SearchResult) {
        let existing = patient.activeDiagnoses
        guard !existing.contains(where: { $0.icdURI == result.id }) else { return }

        // Si no hay diagnósticos activos, el primero es principal; sino secundario
        let type: DiagnosisType = existing.isEmpty ? .principal : .secundario
        let diagnosis = Diagnosis(from: result, diagnosisType: type, patient: patient)
        modelContext.insert(diagnosis)
        auditService.log(action: .create, on: diagnosis, in: modelContext, performedBy: currentActorID, detail: result.theCode)
        patient.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            logger.error("Diagnosis create save failed: \(error, privacy: .private)")
        }
    }

    private func removeActiveDiagnosis(_ diagnosis: Diagnosis) {
        diagnosis.softDelete()
        auditService.log(action: .softDelete, on: diagnosis, in: modelContext, performedBy: currentActorID)
        patient.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            logger.error("Diagnosis softDelete save failed: \(error, privacy: .private)")
        }
    }

    /// Marca un diagnóstico como principal y degrada el anterior principal a secundario
    private func markDiagnosisAsPrimary(_ diagnosis: Diagnosis) {
        for d in patient.activeDiagnoses where d.diagnosisTypeValue.isPrimary {
            d.diagnosisTypeValue = .secundario
        }
        diagnosis.diagnosisTypeValue = .principal
        auditService.log(action: .update, on: diagnosis, in: modelContext, performedBy: currentActorID, detail: "diagnosisType=principal")
        patient.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            logger.error("Diagnosis update save failed: \(error, privacy: .private)")
        }
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
                .buttonStyle(.glassProminent)
            }
        }
    }
}

// MARK: - Quick Info (compact header — avatar + identity + status)

private struct PatientQuickInfo: View {
    let patient: Patient

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            PatientAvatarView(
                photoData: patient.photoData,
                firstName: patient.firstName,
                lastName: patient.lastName,
                genderHint: patient.gender.isEmpty ? patient.biologicalSex : patient.gender,
                clinicalStatus: patient.clinicalStatus,
                size: 52
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(patient.fullName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                ClinicalStatusBadge(status: patient.clinicalStatusValue)

                // .medium weight cuando hay próxima sesión: la línea lleva
                // información accionable y merece un toque más de masa tipográfica.
                // Cuando no hay sesión próxima, .regular mantiene la calma visual.
                Text(metadataLine)
                    .font(.subheadline)
                    .fontWeight(nextAppointmentDate != nil ? .medium : .regular)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var metadataLine: String {
        var parts = ["\(patient.age) años"]
        // Próxima sesión tiene prioridad clínica inmediata sobre el cumpleaños.
        // Integrarla aquí hace el header autosuficiente como snapshot clínico
        // sin necesidad de leer el badge row separado debajo.
        if let next = nextAppointmentDate {
            parts.append("Próx. \(next.esDayMonthAbbrev())")
        } else if let nextBirthday = patient.nextBirthday {
            parts.append("Cumple \(nextBirthday.esDayMonthAbbrev())")
        }
        if let flag = patient.nationality.flagEmoji {
            parts.append(flag)
        }
        return parts.joined(separator: " · ")
    }

    private var accessibilityDescription: String {
        var parts = [patient.fullName, "Estado clínico: \(patient.clinicalStatusValue.label)"]
        parts.append("\(patient.age) años")
        if let next = nextAppointmentDate {
            parts.append("Próxima cita: \(next.esDayMonthAbbrev())")
        }
        if patient.hasOutstandingDebt {
            parts.append("Con deuda pendiente")
        }
        return parts.joined(separator: ". ")
    }

    private var nextAppointmentDate: Date? {
        let today = Calendar.current.startOfDay(for: Date())
        return patient.sessions
            .filter { $0.sessionStatusValue == .programada && $0.sessionDate >= today }
            .map(\.sessionDate)
            .min()
    }
}

// MARK: - Diagnóstico principal (card protagonista)

private struct ActiveDiagnosesCard: View {
    let patient: Patient
    let diagnoses: [Diagnosis]
    let activeDiagnosesAsDTO: [ICD11SearchResult]
    let onAddDiagnosis: (ICD11SearchResult) -> Void
    let onRemoveDiagnosis: (Diagnosis) -> Void
    let onMarkAsPrimary: (Diagnosis) -> Void

    var body: some View {
        if diagnoses.isEmpty {
            // .flat: thinMaterial + glassEffect .clear — peso visual reducido.
            // El diagnóstico es contexto informativo; no compite con Sesiones.
            CardContainer(style: .flat) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("Diagnóstico principal", systemImage: "cross.case")
                        .font(.headline)
                        .foregroundStyle(.primary)

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
                            .font(.subheadline)
                    }
                    .padding(.top, AppSpacing.xs)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Diagnóstico principal. Sin diagnósticos activos.")
            .accessibilityHint("Toque para agregar un diagnóstico")
        } else {
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
                CardContainer(style: .flat) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Label("Diagnóstico principal", systemImage: "cross.case")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }

                        if let primary = diagnoses.first {
                            Text(primary.displayTitle)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)

                            icd11ChipRow(code: primary.icdCode, chapter: primary.icdChapter)
                        }

                        if diagnoses.count > 1 {
                            Text("+\(diagnoses.count - 1) diagnóstico\(diagnoses.count - 1 == 1 ? "" : "s") adicional\(diagnoses.count - 1 == 1 ? "" : "es")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityHint("Abre la lista completa de diagnósticos")
        }
    }

    private var accessibilityDescription: String {
        guard let primary = diagnoses.first else { return "Sin diagnósticos" }
        var label = "Diagnóstico principal: \(primary.displayTitle)"
        if diagnoses.count > 1 {
            label += ". \(diagnoses.count - 1) adicionales"
        }
        return label
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

                icd11ChipRow(code: diagnosis.icdCode, chapter: diagnosis.icdChapter)

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
                    .padding(6)
            }
            .buttonStyle(.glass)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Eliminar diagnóstico \(diagnosis.displayTitle)")
        }
        .contentShape(Rectangle())
    }

    private func isPrimary(_ diagnosis: Diagnosis) -> Bool {
        diagnosis.diagnosisTypeValue.isPrimary
    }

    private func diagnosisTypeLabel(for diagnosis: Diagnosis) -> String {
        diagnosis.diagnosisTypeValue.label
    }
}

// MARK: - ICD-11 chip row (shared between collapsed card and list rows)

/// Fila de píldoras CIE-11: código MMS (énfasis alto) + nombre de capítulo (énfasis bajo).
/// Renderiza nada si ambos campos están vacíos.
@ViewBuilder
private func icd11ChipRow(code: String, chapter: String) -> some View {
    let codeTrimmed = code.trimmed
    let name = icd11ChapterName(for: chapter.trimmed.isEmpty ? nil : chapter.trimmed)
    if !codeTrimmed.isEmpty || !name.isEmpty {
        let color = icd11ChapterColor(for: chapter.trimmed.isEmpty ? nil : chapter.trimmed)
        HStack(spacing: AppSpacing.xs) {
            if !codeTrimmed.isEmpty {
                ICD11ChipView(text: codeTrimmed, color: color, emphasis: .high)
            }
            if !name.isEmpty {
                ICD11ChipView(text: name, color: color, emphasis: .low)
            }
        }
    }
}

// MARK: - Clinical module row (reusable navigation row with metadata)

private struct ClinicalModuleRow<Destination: View>: View {
    let title: String
    let systemImage: String
    let detail: String
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            CardContainer(style: .flat) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: systemImage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
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
    @State private var addSessionBounce: Int = 0
    // Sheet de edición — mismo modelo de presentación que la creación.
    // HIG: crear y editar la misma entidad deben usar el mismo patrón modal.
    @State private var sessionToEdit: Session? = nil

    private static let visibleLimit = 3

    private var sortedSessions: [Session] {
        patient.sessions.sorted { $0.sessionDate > $1.sessionDate }
    }

    private var visibleSessions: [Session] {
        Array(sortedSessions.prefix(Self.visibleLimit))
    }

    var body: some View {
        // .elevated: regularMaterial + glassEffect .regular + radio 20 + sombra mayor.
        // Sessions es la sección primaria — su peso visual debe dominarlo todo.
        CardContainer(style: .elevated) {
            // lg (24pt) en lugar de md (16pt): las secciones hero tienen más aire
            // interno, lo que el ojo interpreta como mayor peso sin cambiar tamaño.
            VStack(spacing: AppSpacing.lg) {
                // Header: título + botón "+" — solo visible cuando hay sesiones.
                // En estado vacío, el CTA explícito ("Crear primera sesión") es la
                // única acción primaria, siguiendo las guías de Apple para empty states.
                HStack {
                    // title2 > title3: un escalón tipográfico arriba para señalar
                    // que esta sección es la de mayor jerarquía en la pantalla.
                    Text("Sesiones")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    if !sortedSessions.isEmpty {
                        Button {
                            addSessionBounce += 1
                            onCreateSession()
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .frame(width: 28, height: 28)
                                .symbolEffect(.bounce, value: addSessionBounce)
                        }
                        .buttonStyle(.glass)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Nueva sesión")
                        // .sensoryFeedback reemplaza UIImpactFeedbackGenerator:
                        // es puro SwiftUI y respeta automáticamente la
                        // configuración del sistema (Reduce Motion, Haptics off).
                        .sensoryFeedback(.impact(weight: .light), trigger: addSessionBounce)
                    }
                }

                if sortedSessions.isEmpty {
                    // Estado vacío centrado con padding vertical generoso:
                    // el área en blanco refuerza que este es el espacio a completar.
                    // Alineación central y escala de texto mayor que en secciones
                    // secundarias — coherente con ContentUnavailableView de Apple.
                    VStack(alignment: .center, spacing: AppSpacing.sm) {
                        Text("No hay sesiones registradas")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Button {
                            addSessionBounce += 1
                            onCreateSession()
                        } label: {
                            Label("Crear primera sesión", systemImage: "plus.circle")
                                .font(.body.weight(.medium))
                                .symbolEffect(.bounce, value: addSessionBounce)
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: addSessionBounce)
                    }
                    .padding(.vertical, AppSpacing.lg)
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
        .sheet(item: $sessionToEdit) { session in
            NavigationStack {
                SessionFormView(patient: patient, session: session)
            }
        }
        .sheet(item: $pendingCompletion) { item in
            PaymentFlowView(draft: item.completionDraft, onCancel: {}) { paymentIntent in
                try sessionViewModel.completeSession(item.session, in: modelContext, paymentIntent: paymentIntent)
            }
        }
        .alert("No se pudo completar la sesión", isPresented: $completionErrorMessage.isPresent) {
            Button("Aceptar", role: .cancel) {
                completionErrorMessage = nil
            }
        } message: {
            Text(completionErrorMessage ?? "Ocurrió un error al registrar el cierre.")
        }
        // Feedback de selección al tocar una fila de sesión.
        // La forma closure devuelve nil en el dismiss (sessionToEdit → nil)
        // para evitar doble haptic: solo dispara al abrir, no al cerrar.
        .sensoryFeedback(trigger: sessionToEdit) {
            sessionToEdit != nil ? .selection : nil
        }
    }

    @ViewBuilder
    private func sessionListItem(for session: Session, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Button {
                sessionToEdit = session
            } label: {
                SessionRowView(
                    session: session,
                    isFirst: isFirst,
                    isLast: isLast
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHint("Abre la sesión para editar")

            if canCompleteSession(session) {
                Button {
                    openCompletionFlow(for: session)
                } label: {
                    Text("Completar")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.glass)
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

}


// MARK: - Historial completo de sesiones

private struct SessionHistoryListView: View {
    let patient: Patient

    private var sortedSessions: [Session] {
        patient.sessions.sorted { $0.sessionDate > $1.sessionDate }
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

                    // — Contacto (condicional)
                    if hasContactData {
                        sectionHeader("Contacto")
                        contactContent
                    }

                    // — Registro
                    sectionHeader("Registro")
                    auditContent

                    // — Acciones (subdued)
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

    @ViewBuilder
    private var contactContent: some View {
        VStack(spacing: 12) {
            if !patient.email.isEmpty {
                DataRowView(icon: "envelope", title: "Email", value: patient.email)
            }
            if !patient.phoneNumber.isEmpty {
                PhoneContactRowView(
                    phoneNumber: patient.phoneNumber,
                    isoCountryCode: patient.residenceCountry.isEmpty ? nil : patient.residenceCountry
                )
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
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Button {
                onRestore()
            } label: {
                Label("Restaurar Paciente", systemImage: "arrow.counterclockwise")
                    .font(.footnote)
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

// MARK: - Phone Contact Row

/// Fila de contacto telefónico con acciones rápidas de llamada y WhatsApp.
/// El ícono de WhatsApp sólo aparece si la app está instalada y el número es válido.
private struct PhoneContactRowView: View {

    let phoneNumber: String
    /// Código ISO 3166-1 alpha-2 del paciente (ej. "ES", "AR").
    /// Se usa para inferir el indicativo cuando el número se guardó en formato local.
    var isoCountryCode: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(.body)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Teléfono")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(phoneNumber)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)

            // Llamada
            if let callURL = PhoneContact.callURL(for: phoneNumber) {
                Button {
                    UIApplication.shared.open(callURL)
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.callout)
                        .foregroundStyle(.tint)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Llamar al paciente")
                .accessibilityHint("Abre la app de Teléfono para llamar a \(phoneNumber)")
            }

            // WhatsApp — solo si está instalado y el número normaliza correctamente
            if PhoneContact.isWhatsAppAvailable,
               let normalized = PhoneContact.normalizedForWhatsApp(phoneNumber, isoCountryCode: isoCountryCode),
               let waURL = PhoneContact.whatsAppURL(normalizedPhone: normalized) {
                Button {
                    UIApplication.shared.open(waURL)
                } label: {
                    Image(systemName: "message.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Abrir chat de WhatsApp con el paciente")
                .accessibilityHint("Abre WhatsApp en la conversación con \(phoneNumber)")
            }
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

                Text(L10n.tr("patient.pdf.title", patientName))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(fileURL.lastPathComponent)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ShareLink(
                    item: fileURL,
                    preview: SharePreview(L10n.tr("patient.pdf.title", patientName))
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
