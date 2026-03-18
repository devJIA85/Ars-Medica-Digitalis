//
//  PatientMedicalHistoryFormView.swift
//  Ars Medica Digitalis
//
//  Formulario editable de historia clínica con layout tipo card,
//  autosave debounceado y modo de concentración clínica.
//

import SwiftUI
import SwiftData

struct PatientMedicalHistoryFormView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let patient: Patient

    // @State preserva el VM entre re-renders (al cerrar sheets de medicamentos).
    @State private var viewModel: PatientViewModel

    @State private var selectedMedications: [Medication] = []
    @State private var initialSelectedMedicationIDs: Set<UUID> = []
    @State private var didTouchMedicationSelection: Bool = false
    @State private var showingMedicationPicker: Bool = false
    @State private var infoMedication: Medication? = nil

    @State private var isClinicalFocusMode: Bool = true
    @State private var focusedSection: ClinicalSection = .medication
    @State private var activeAnthropometricField: AnthropometricField? = nil

    @State private var weightText: String
    @State private var heightText: String
    @State private var waistText: String

    @State private var didInitializeState: Bool = false
    @State private var lastPersistedSignature: String = ""
    @State private var autosaveState: AutosaveState = .idle
    @State private var voiceInputManager: VoiceInputManager = VoiceInputManager()

    init(patient: Patient) {
        self.patient = patient
        let vm = PatientViewModel()
        vm.load(from: patient)
        _viewModel = State(initialValue: vm)
        _weightText = State(initialValue: Self.metricText(from: vm.weightKg))
        _heightText = State(initialValue: Self.metricText(from: vm.heightCm))
        _waistText = State(initialValue: Self.metricText(from: vm.waistCm))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isClinicalFocusMode ? AppSpacing.md : AppSpacing.sectionGap) {
                if isClinicalFocusMode {
                    concentrationBanner
                }

                ClinicalCardContainer(
                    title: ClinicalSection.medication.title,
                    systemImage: ClinicalSection.medication.systemImage,
                    style: isFocusedSection(.medication) ? .elevated : .flat,
                    isCollapsed: isSectionCollapsed(.medication),
                    onHeaderTap: {
                        focus(on: .medication)
                    }
                ) {
                    MedicationHistorySection(
                        selectedMedications: sortedSelectedMedications,
                        currentMedicationText: viewModel.currentMedication,
                        isVoiceActive: isVoiceCaptureActive(for: .medicationLegacy),
                        onAddMedication: {
                            focus(on: .medication)
                            showingMedicationPicker = true
                        },
                        onVoiceTap: {
                            toggleVoiceCapture(for: .medicationLegacy, section: .medication)
                        },
                        onRemoveMedication: { medication in
                            focus(on: .medication)
                            removeMedication(medication)
                        },
                        onShowMedicationInfo: { medication in
                            focus(on: .medication)
                            infoMedication = medication
                        }
                    )
                }
                .opacity(cardOpacity(for: .medication))

                ClinicalCardContainer(
                    title: ClinicalSection.lifestyle.title,
                    systemImage: ClinicalSection.lifestyle.systemImage,
                    style: isFocusedSection(.lifestyle) ? .elevated : .flat,
                    isCollapsed: isSectionCollapsed(.lifestyle),
                    onHeaderTap: {
                        activeAnthropometricField = nil
                        focus(on: .lifestyle)
                    }
                ) {
                    LifestyleSection(viewModel: viewModel)
                }
                .opacity(cardOpacity(for: .lifestyle))

                ClinicalCardContainer(
                    title: ClinicalSection.familyHistory.title,
                    systemImage: ClinicalSection.familyHistory.systemImage,
                    style: isFocusedSection(.familyHistory) ? .elevated : .flat,
                    isCollapsed: isSectionCollapsed(.familyHistory),
                    onHeaderTap: {
                        activeAnthropometricField = nil
                        focus(on: .familyHistory)
                    }
                ) {
                    FamilyHistoryFormSection(
                        viewModel: viewModel,
                        isVoiceActive: isVoiceCaptureActive(for: .familyHistoryOther),
                        onBeginEditingOther: {
                            activeAnthropometricField = nil
                            focus(on: .familyHistory)
                        },
                        onVoiceTap: {
                            toggleVoiceCapture(for: .familyHistoryOther, section: .familyHistory)
                        }
                    )
                }
                .opacity(cardOpacity(for: .familyHistory))

                ClinicalCardContainer(
                    title: ClinicalSection.anthropometry.title,
                    systemImage: ClinicalSection.anthropometry.systemImage,
                    style: isFocusedSection(.anthropometry) ? .elevated : .flat,
                    isCollapsed: isSectionCollapsed(.anthropometry),
                    onHeaderTap: {
                        focus(on: .anthropometry)
                    }
                ) {
                    AnthropometrySection(
                        weightText: weightText,
                        heightText: heightText,
                        waistText: waistText,
                        activeField: activeAnthropometricField,
                        decimalSeparator: decimalSeparator,
                        bmiText: bmiText,
                        bmiColor: bmiColor,
                        isVoiceActive: { field in
                            isVoiceCaptureActive(for: field.voiceField)
                        },
                        onSelectField: { field in
                            focus(on: .anthropometry)
                            activeAnthropometricField = field
                        },
                        onVoiceTap: { field in
                            toggleVoiceCapture(for: field.voiceField, section: .anthropometry)
                        },
                        onNumericKey: { key in
                            applyNumericKey(key)
                        }
                    )
                }
                .opacity(cardOpacity(for: .anthropometry))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .backgroundExtensionEffect()
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("Historia Clínica")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle(autosaveSubtitle)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.smooth(duration: 0.20)) {
                        isClinicalFocusMode.toggle()
                    }
                    activeAnthropometricField = nil
                } label: {
                    Label(
                        isClinicalFocusMode ? "Concentrado" : "Completo",
                        systemImage: isClinicalFocusMode ? "scope" : "rectangle.grid.1x2"
                    )
                }
                .buttonStyle(.glass)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    activeAnthropometricField = nil
                    persistMedicalHistory(shouldDismiss: true, createAnthropometricRecord: true)
                }
            }
        }
        .sheet(isPresented: $showingMedicationPicker) {
            MedicationPickerSheet(selectedMedications: $selectedMedications)
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
        .onAppear {
            initializeStateIfNeeded()
        }
        .onChange(of: Set(selectedMedications.map(\.id))) { _, newValue in
            didTouchMedicationSelection = newValue != initialSelectedMedicationIDs
        }
        .task(id: autosaveTaskID) {
            await runAutosaveIfNeeded()
        }
    }

    // MARK: - Helpers

    private static func metricText(from value: Double) -> String {
        guard value > 0 else { return "" }
        let rounded = value.rounded()
        if abs(rounded - value) < 0.01 {
            return String(Int(rounded))
        }
        let formatted = String(format: "%.1f", value)
        return formatted.hasSuffix(".0")
            ? String(formatted.dropLast(2))
            : formatted
    }

    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    private var concentrationBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Label("Modo concentración", systemImage: "scope")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(focusedSection.focusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Voz: \(voiceCaptureStatusLabel)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var sortedSelectedMedications: [Medication] {
        selectedMedications.sorted {
            if $0.principioActivo.caseInsensitiveCompare($1.principioActivo) == .orderedSame {
                return $0.nombreComercial.localizedCaseInsensitiveCompare($1.nombreComercial) == .orderedAscending
            }
            return $0.principioActivo.localizedCaseInsensitiveCompare($1.principioActivo) == .orderedAscending
        }
    }

    private var bmiColor: Color {
        guard let bmi = viewModel.bmi, let category = BMICategory(bmi: bmi) else { return .secondary }
        return category.color
    }

    private var bmiText: String? {
        guard let bmi = viewModel.bmi else { return nil }
        return String(format: "%.1f · %@", bmi, viewModel.bmiCategory)
    }

    private var autosaveSignature: String {
        let medicationIDs = sortedSelectedMedications
            .map(\.id.uuidString)
            .joined(separator: ",")

        return [
            String(format: "%.2f", viewModel.weightKg),
            String(format: "%.2f", viewModel.heightCm),
            String(format: "%.2f", viewModel.waistCm),
            viewModel.familyHistoryOther.trimmed,
            boolToken(viewModel.smokingStatus),
            boolToken(viewModel.alcoholUse),
            boolToken(viewModel.drugUse),
            boolToken(viewModel.routineCheckups),
            boolToken(viewModel.familyHistoryHTA),
            boolToken(viewModel.familyHistoryACV),
            boolToken(viewModel.familyHistoryCancer),
            boolToken(viewModel.familyHistoryDiabetes),
            boolToken(viewModel.familyHistoryHeartDisease),
            boolToken(viewModel.familyHistoryMentalHealth),
            boolToken(didTouchMedicationSelection),
            medicationIDs,
            // Arquitectura de voz: solo señal estable, nunca transcript volátil.
            voiceInputManager.stableAutosaveSignature,
        ].joined(separator: "|")
    }

    private var autosaveTaskID: String {
        "\(autosaveSignature)|field:\(activeAnthropometricField?.rawValue ?? "none")"
    }

    private var autosaveSubtitle: String {
        switch autosaveState {
        case .idle:
            return "Autosave activo"
        case .saving:
            return "Guardando..."
        case .saved(let date):
            let elapsed = Int(Date().timeIntervalSince(date))
            if elapsed < 5 { return "Guardado ahora" }
            if elapsed < 60 { return "Guardado hace \(elapsed)s" }
            return "Guardado hace \(elapsed / 60)m"
        }
    }

    private func boolToken(_ value: Bool) -> String {
        value ? "1" : "0"
    }

    private func focus(on section: ClinicalSection) {
        focusedSection = section
    }

    private var voiceCaptureStatusLabel: String {
        switch voiceInputManager.captureMode {
        case .idle:
            return "stub"
        case .armed(let field):
            return "listo en \(field.label.lowercased())"
        case .capturing(let field):
            return "capturando \(field.label.lowercased())"
        case .finishing(let field):
            return "finalizando \(field.label.lowercased())"
        }
    }

    private func isVoiceCaptureActive(for field: ClinicalVoiceField) -> Bool {
        voiceInputManager.activeField == field
    }

    private func toggleVoiceCapture(for field: ClinicalVoiceField, section: ClinicalSection) {
        focus(on: section)

        if isVoiceCaptureActive(for: field) {
            voiceInputManager.stopCapture()
            if AnthropometricField.voiceFields.contains(field) {
                activeAnthropometricField = nil
            }
            return
        }

        voiceInputManager.toggleCapture(for: field)
        if let anthropometricField = AnthropometricField(voiceField: field) {
            activeAnthropometricField = anthropometricField
        } else {
            activeAnthropometricField = nil
        }
    }

    private func isFocusedSection(_ section: ClinicalSection) -> Bool {
        isClinicalFocusMode && focusedSection == section
    }

    private func cardOpacity(for section: ClinicalSection) -> Double {
        guard isClinicalFocusMode, focusedSection != section else { return 1.0 }
        return 0.82
    }

    private func isSectionCollapsed(_ section: ClinicalSection) -> Bool {
        isClinicalFocusMode && focusedSection != section
    }

    private func initializeStateIfNeeded() {
        guard !didInitializeState else { return }

        let medications = uniqueMedications(patient.currentMedications ?? [])
        selectedMedications = medications
        initialSelectedMedicationIDs = Set(medications.map(\.id))
        didTouchMedicationSelection = false

        syncViewModelFromMetricText()

        lastPersistedSignature = autosaveSignature
        autosaveState = .saved(Date())
        didInitializeState = true
    }

    private func runAutosaveIfNeeded() async {
        guard didInitializeState else { return }
        guard activeAnthropometricField == nil else { return }

        let signature = autosaveSignature
        guard signature != lastPersistedSignature else { return }

        await MainActor.run {
            autosaveState = .saving
        }
        try? await Task.sleep(for: .milliseconds(650))
        guard !Task.isCancelled else { return }

        await MainActor.run {
            persistMedicalHistory(shouldDismiss: false, createAnthropometricRecord: true)
        }
    }

    private func removeMedication(_ medication: Medication) {
        selectedMedications.removeAll { $0.id == medication.id }
    }

    private func uniqueMedications(_ medications: [Medication]) -> [Medication] {
        var seen = Set<UUID>()
        var unique: [Medication] = []

        for medication in medications {
            guard seen.insert(medication.id).inserted else { continue }
            unique.append(medication)
        }

        return unique
    }

    private func persistMedicalHistory(shouldDismiss: Bool, createAnthropometricRecord: Bool) {
        syncViewModelFromMetricText()

        if createAnthropometricRecord {
            // Crear registro histórico ANTES de actualizar.
            viewModel.createAnthropometricRecordIfNeeded(for: patient, in: modelContext)
        }

        let uniqueSelection = uniqueMedications(sortedSelectedMedications)
        patient.currentMedications = uniqueSelection

        if uniqueSelection.isEmpty {
            // Compatibilidad: si no se toco el selector, conservar texto legacy.
            if didTouchMedicationSelection {
                viewModel.currentMedication = ""
            } else {
                viewModel.currentMedication = patient.currentMedication
            }
        } else {
            viewModel.currentMedication = uniqueSelection
                .map(\.summaryLabel)
                .joined(separator: " · ")
        }

        viewModel.update(patient)
        lastPersistedSignature = autosaveSignature
        autosaveState = .saved(Date())

        if shouldDismiss {
            dismiss()
        }
    }

    private func metricText(for field: AnthropometricField) -> String {
        switch field {
        case .weight: return weightText
        case .height: return heightText
        case .waist: return waistText
        }
    }

    private func setMetricText(_ value: String, for field: AnthropometricField) {
        switch field {
        case .weight:
            weightText = value
        case .height:
            heightText = value
        case .waist:
            waistText = value
        }
    }

    private func applyNumericKey(_ key: NumericKey) {
        guard let field = activeAnthropometricField else { return }

        if key == .done {
            activeAnthropometricField = nil
            return
        }

        var value = metricText(for: field)

        switch key {
        case .digit(let digit):
            if value == "0" {
                value = digit
            } else {
                value.append(digit)
            }
        case .decimal:
            if !value.contains(decimalSeparator) {
                value = value.isEmpty ? "0\(decimalSeparator)" : value + decimalSeparator
            }
        case .backspace:
            if !value.isEmpty {
                value.removeLast()
            }
        case .clear:
            value = ""
        case .done:
            break
        }

        let sanitized = sanitizedMetricText(value)
        setMetricText(sanitized, for: field)
        syncViewModelFromMetricText()
    }

    private func sanitizedMetricText(_ raw: String) -> String {
        var result: String = ""
        var hasSeparator = false

        for character in raw {
            if character.isNumber {
                result.append(character)
                continue
            }

            let token = String(character)
            if (token == "." || token == "," || token == decimalSeparator),
                !hasSeparator
            {
                hasSeparator = true
                if result.isEmpty {
                    result = "0"
                }
                result.append(decimalSeparator)
            }
        }

        return result
    }

    private func parseMetricText(_ text: String) -> Double {
        let normalized = text
            .replacingOccurrences(of: decimalSeparator, with: ".")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private func syncViewModelFromMetricText() {
        viewModel.weightKg = parseMetricText(weightText)
        viewModel.heightCm = parseMetricText(heightText)
        viewModel.waistCm = parseMetricText(waistText)
    }
}

private enum ClinicalSection: String, CaseIterable {
    case medication
    case lifestyle
    case familyHistory
    case anthropometry

    var title: String {
        switch self {
        case .medication:
            "Medicación Actual"
        case .lifestyle:
            "Estilo de Vida"
        case .familyHistory:
            "Antecedentes Familiares"
        case .anthropometry:
            "Antropometría"
        }
    }

    var systemImage: String {
        switch self {
        case .medication:
            "pills.fill"
        case .lifestyle:
            "figure.walk"
        case .familyHistory:
            "person.3.sequence.fill"
        case .anthropometry:
            "ruler"
        }
    }

    var focusLabel: String {
        switch self {
        case .medication:
            "Foco: medicación"
        case .lifestyle:
            "Foco: hábitos"
        case .familyHistory:
            "Foco: familiares"
        case .anthropometry:
            "Foco: mediciones"
        }
    }
}

private enum AnthropometricField: String, Hashable {
    case weight
    case height
    case waist

    var voiceField: ClinicalVoiceField {
        switch self {
        case .weight:
            return .weight
        case .height:
            return .height
        case .waist:
            return .waist
        }
    }

    static let voiceFields: Set<ClinicalVoiceField> = [.weight, .height, .waist]

    init?(voiceField: ClinicalVoiceField) {
        switch voiceField {
        case .weight:
            self = .weight
        case .height:
            self = .height
        case .waist:
            self = .waist
        default:
            return nil
        }
    }
}

private enum NumericKey: Hashable {
    case digit(String)
    case decimal
    case backspace
    case clear
    case done
}

private enum AutosaveState {
    case idle
    case saving
    case saved(Date)
}

private struct MedicationHistorySection: View {

    let selectedMedications: [Medication]
    let currentMedicationText: String
    let isVoiceActive: Bool
    let onAddMedication: () -> Void
    let onVoiceTap: () -> Void
    let onRemoveMedication: (Medication) -> Void
    let onShowMedicationInfo: (Medication) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if selectedMedications.isEmpty {
                Text("Sin medicación registrada")
                    .foregroundStyle(.secondary)

                if !currentMedicationText.trimmed.isEmpty {
                    LabeledContent("Texto previo") {
                        Text(currentMedicationText)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)
                }
            } else {
                ForEach(selectedMedications) { medication in
                    SelectedMedicationRow(
                        medication: medication,
                        onRemove: {
                            onRemoveMedication(medication)
                        },
                        onInfo: {
                            onShowMedicationInfo(medication)
                        }
                    )

                    if medication.id != selectedMedications.last?.id {
                        Divider()
                            .opacity(0.25)
                    }
                }
            }

            HStack(spacing: AppSpacing.sm) {
                Button {
                    onAddMedication()
                } label: {
                    Label("Agregar medicamentos", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer(minLength: 0)

                VoiceFieldButton(
                    isActive: isVoiceActive,
                    accessibilityLabel: "Micrófono para \(ClinicalVoiceField.medicationLegacy.label.lowercased())",
                    action: onVoiceTap
                )
            }
            .padding(.top, AppSpacing.xs)
        }
    }
}

private struct LifestyleSection: View {

    @Bindable var viewModel: PatientViewModel

    var body: some View {
        VStack(spacing: 0) {
            ClinicalToggleRow(title: "Tabaquismo", isOn: $viewModel.smokingStatus)
            Divider().opacity(0.25)
            ClinicalToggleRow(title: "Consumo de alcohol", isOn: $viewModel.alcoholUse)
            Divider().opacity(0.25)
            ClinicalToggleRow(title: "Consumo de drogas", isOn: $viewModel.drugUse)
            Divider().opacity(0.25)
            ClinicalToggleRow(title: "Chequeos médicos de rutina", isOn: $viewModel.routineCheckups)
        }
    }
}

private struct FamilyHistoryFormSection: View {

    @Bindable var viewModel: PatientViewModel
    let isVoiceActive: Bool
    let onBeginEditingOther: () -> Void
    let onVoiceTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(spacing: 0) {
                ClinicalToggleRow(title: "Hipertensión arterial (HTA)", isOn: $viewModel.familyHistoryHTA)
                Divider().opacity(0.25)
                ClinicalToggleRow(title: "ACV", isOn: $viewModel.familyHistoryACV)
                Divider().opacity(0.25)
                ClinicalToggleRow(title: "Cáncer", isOn: $viewModel.familyHistoryCancer)
                Divider().opacity(0.25)
                ClinicalToggleRow(title: "Diabetes", isOn: $viewModel.familyHistoryDiabetes)
                Divider().opacity(0.25)
                ClinicalToggleRow(title: "Enfermedad cardíaca", isOn: $viewModel.familyHistoryHeartDisease)
                Divider().opacity(0.25)
                ClinicalToggleRow(title: "Salud mental", isOn: $viewModel.familyHistoryMentalHealth)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Otros antecedentes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    TextField("Detalle breve", text: $viewModel.familyHistoryOther, axis: .vertical)
                        .lineLimit(1...2)
                        .lineHeight(.leading(increase: 2))
                        .textInputAutocapitalization(.sentences)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.sm)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous))
                        .onTapGesture {
                            onBeginEditingOther()
                        }

                    VoiceFieldButton(
                        isActive: isVoiceActive,
                        accessibilityLabel: "Micrófono para \(ClinicalVoiceField.familyHistoryOther.label.lowercased())",
                        action: onVoiceTap
                    )
                }
            }
        }
    }
}

private struct AnthropometrySection: View {

    let weightText: String
    let heightText: String
    let waistText: String
    let activeField: AnthropometricField?
    let decimalSeparator: String
    let bmiText: String?
    let bmiColor: Color
    let isVoiceActive: (AnthropometricField) -> Bool
    let onSelectField: (AnthropometricField) -> Void
    let onVoiceTap: (AnthropometricField) -> Void
    let onNumericKey: (NumericKey) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(spacing: 0) {
                AnthropometricMetricRow(
                    title: "Peso (kg)",
                    valueText: weightText,
                    isActive: activeField == .weight,
                    isMicActive: isVoiceActive(.weight),
                    onTap: {
                        onSelectField(.weight)
                    },
                    onMicTap: {
                        onVoiceTap(.weight)
                    }
                )
                Divider().opacity(0.25)

                AnthropometricMetricRow(
                    title: "Altura (cm)",
                    valueText: heightText,
                    isActive: activeField == .height,
                    isMicActive: isVoiceActive(.height),
                    onTap: {
                        onSelectField(.height)
                    },
                    onMicTap: {
                        onVoiceTap(.height)
                    }
                )
                Divider().opacity(0.25)

                AnthropometricMetricRow(
                    title: "Cintura (cm)",
                    valueText: waistText,
                    isActive: activeField == .waist,
                    isMicActive: isVoiceActive(.waist),
                    onTap: {
                        onSelectField(.waist)
                    },
                    onMicTap: {
                        onVoiceTap(.waist)
                    }
                )

                if let bmiText {
                    Divider().opacity(0.25)
                    HStack(spacing: AppSpacing.sm) {
                        Text("IMC")
                        Spacer(minLength: 0)
                        Text(bmiText)
                            .foregroundStyle(bmiColor)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
            }

        if activeField != nil {
            InlineNumericKeyboard(
                decimalSeparator: decimalSeparator,
                onPress: onNumericKey
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    .animation(.smooth(duration: 0.20), value: activeField)
}
}

private struct AnthropometricMetricRow: View {

    let title: String
    let valueText: String
    let isActive: Bool
    let isMicActive: Bool
    let onTap: () -> Void
    let onMicTap: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Text(valueText.isEmpty ? "Tocar para cargar" : valueText)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(valueText.isEmpty ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xs)
            .background(
                isActive ? Color.accentColor.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            VoiceFieldButton(
                isActive: isMicActive,
                accessibilityLabel: "Micrófono para \(title)",
                action: onMicTap
            )
        }
    }
}

private struct InlineNumericKeyboard: View {

    let decimalSeparator: String
    let onPress: (NumericKey) -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 3)
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                NumericPadKey(title: "1") { onPress(.digit("1")) }
                NumericPadKey(title: "2") { onPress(.digit("2")) }
                NumericPadKey(title: "3") { onPress(.digit("3")) }

                NumericPadKey(title: "4") { onPress(.digit("4")) }
                NumericPadKey(title: "5") { onPress(.digit("5")) }
                NumericPadKey(title: "6") { onPress(.digit("6")) }

                NumericPadKey(title: "7") { onPress(.digit("7")) }
                NumericPadKey(title: "8") { onPress(.digit("8")) }
                NumericPadKey(title: "9") { onPress(.digit("9")) }

                NumericPadKey(title: decimalSeparator) { onPress(.decimal) }
                NumericPadKey(title: "0") { onPress(.digit("0")) }
                NumericPadKey(systemImage: "delete.left") { onPress(.backspace) }
            }

            HStack(spacing: AppSpacing.sm) {
                NumericPadKey(title: "Borrar", isPrimary: false) {
                    onPress(.clear)
                }

                NumericPadKey(title: "Listo", isPrimary: true) {
                    onPress(.done)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
    }
}

private struct NumericPadKey: View {

    let title: String?
    let systemImage: String?
    var isPrimary: Bool = false
    let action: () -> Void

    init(title: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = nil
        self.isPrimary = isPrimary
        self.action = action
    }

    init(systemImage: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = nil
        self.systemImage = systemImage
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if let title {
                    Text(title)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(isPrimary ? .white : .primary)
            .background(
                isPrimary ? Color.accentColor : Color.primary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct VoiceFieldButton: View {

    let isActive: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: isActive ? "mic.fill" : "mic")
                .font(.body.weight(.semibold))
                .foregroundStyle(isActive ? .white : .secondary)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, options: .repeating, isActive: isActive)
                .frame(width: 34, height: 34)
                .background(
                    isActive ? Color.accentColor : Color.primary.opacity(0.08),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ClinicalToggleRow: View {

    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct SelectedMedicationRow: View {

    let medication: Medication
    let onRemove: () -> Void
    let onInfo: () -> Void

    var body: some View {
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
                onInfo()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.plain)
        }
    }
}
