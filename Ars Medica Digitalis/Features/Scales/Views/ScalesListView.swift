//
//  ScalesListView.swift
//  Ars Medica Digitalis
//
//  Lista de escalas clínicas disponibles para un paciente.
//

import SwiftUI
import SwiftData

struct ScalesListView: View {

    @Environment(\.dismiss) private var dismiss

    let patientID: UUID
    let patientName: String

    @Query private var savedResults: [PatientScaleResult]

    @State private var scales: [ClinicalScale] = []
    @State private var mmseTest: MMSETest? = nil
    @State private var loadErrorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var selectedScaleFlow: SelectedScaleFlow? = nil

    init(patientID: UUID, patientName: String) {
        self.patientID = patientID
        self.patientName = patientName

        let patientIdentifier = patientID
        _savedResults = Query(
            filter: #Predicate<PatientScaleResult> { result in
                result.patientID == patientIdentifier
            },
            sort: [SortDescriptor(\PatientScaleResult.date, order: .reverse)]
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                headerCard

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, AppSpacing.lg)
                } else if scales.isEmpty && mmseTest == nil {
                    ContentUnavailableView(
                        "Sin escalas disponibles",
                        systemImage: "list.bullet.clipboard",
                        description: Text(loadErrorMessage ?? "No se encontraron escalas válidas.")
                    )
                } else {
                    VStack(spacing: AppSpacing.md) {
                        if let mmseTest {
                            mmseRow(mmseTest)
                        }

                        ForEach(scales) { scale in
                            scaleRow(scale)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Escalas")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $selectedScaleFlow, onDismiss: resetSelectedScaleFlow) { flow in
            fullScreenDestination(for: flow)
        }
        .task {
            await loadScales()
        }
        .refreshable {
            await loadScales()
        }
    }

    private var headerCard: some View {
        CardContainer(
            style: .flat,
            usesGlassEffect: false,
            backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("Paciente", systemImage: "person.text.rectangle")
                    .font(.headline.weight(.semibold))

                Text(patientName)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("Seleccioná una escala para iniciar la evaluación clínica.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func scaleRow(_ scale: ClinicalScale) -> some View {
        Button {
            selectedScaleFlow = .clinical(
                scale: scale,
                savedResults: savedResultSnapshotsForScale(scale.id)
            )
        } label: {
            CardContainer(
                style: .flat,
                usesGlassEffect: false,
                backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
            ) {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "waveform.path.ecg")
                                .symbolRenderingMode(.hierarchical)
                                .symbolColorRenderingMode(.gradient)
                                .foregroundStyle(Color.accentColor)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(scale.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("\(scale.items.count) preguntas · \(subtitleText(for: scale))")
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
        .accessibilityLabel(scale.name)
        .accessibilityIdentifier("scale.row.\(scale.id)")
    }

    /// Fila dedicada al MMSE para integrarlo en la misma lista de escalas clínicas.
    /// Se usa el test cargado desde JSON para mantener la UI completamente data-driven.
    private func mmseRow(_ test: MMSETest) -> some View {
        Button {
            selectedScaleFlow = .mmse(test: test)
        } label: {
            CardContainer(
                style: .flat,
                usesGlassEffect: false,
                backgroundStyle: .solid(Color(uiColor: .secondarySystemGroupedBackground))
            ) {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "brain.head.profile")
                                .symbolRenderingMode(.hierarchical)
                                .symbolColorRenderingMode(.gradient)
                                .foregroundStyle(Color.accentColor)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(test.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(mmseSubtitleText(for: test))
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
        .accessibilityLabel(test.name)
        .accessibilityIdentifier("scale.row.\(test.id)")
    }

    @MainActor
    private func loadScales() async {
        isLoading = true
        defer { isLoading = false }

        var loadedScales: [ClinicalScale] = []
        var loadedMMSE: MMSETest? = nil
        var errors: [String] = []

        do {
            loadedScales = try ScaleLoader.loadAll()
        } catch {
            errors.append(error.localizedDescription)
        }

        do {
            loadedMMSE = try await MMSELoader().load()
        } catch {
            errors.append(error.localizedDescription)
        }

        scales = loadedScales
        mmseTest = loadedMMSE
        loadErrorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    private func subtitleText(for scale: ClinicalScale) -> String {
        guard let latestResult = latestResultByScaleID[scale.id] else {
            return scale.timeframe.displayLabel
        }

        let interpretation = scale.scoring.interpretation(for: latestResult.totalScore)?.label
            ?? latestResult.severity.capitalized
        return "Último: \(interpretation) · Score \(latestResult.totalScore)"
    }

    private func mmseSubtitleText(for test: MMSETest) -> String {
        guard let latestResult = latestResultByScaleID[test.id] else {
            return "\(test.maximumScore) puntos · \(test.sections.count) secciones"
        }

        let interpretation = test.scoring.interpretation(for: latestResult.totalScore)?.label
            ?? latestResult.severity.capitalized
        return "Último: \(interpretation) · Score \(latestResult.totalScore)"
    }

    private var latestResultByScaleID: [String: PatientScaleResult] {
        var map: [String: PatientScaleResult] = [:]
        for result in savedResults where map[result.scaleID] == nil {
            map[result.scaleID] = result
        }
        return map
    }

    @MainActor
    private func savedResultSnapshotsForScale(_ scaleID: String) -> [SavedScaleResultSnapshot] {
        savedResults
            .filter { $0.scaleID == scaleID }
            .map(SavedScaleResultSnapshot.init)
    }

    private func resetSelectedScaleFlow() {
        selectedScaleFlow = nil
    }

    /// Router central para cada flujo de evaluación mostrado como full-screen.
    /// Se separa por tipo para mantener navegación consistente sin acoplar modelos distintos.
    @ViewBuilder
    private func fullScreenDestination(for flow: SelectedScaleFlow) -> some View {
        switch flow {
        case .clinical(let scale, let savedResults):
            NavigationStack {
                ScaleIntroView(
                    scale: scale,
                    patientID: patientID,
                    patientName: patientName,
                    savedResults: savedResults,
                    onSessionSaved: {
                        selectedScaleFlow = nil
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedScaleFlow = nil
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Volver")
                    }
                }
            }
        case .mmse(let test):
            NavigationStack {
                MMSEIntroView(
                    test: test,
                    patientID: patientID,
                    patientName: patientName
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            selectedScaleFlow = nil
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Volver")
                    }
                }
            }
        }
    }
}

private enum SelectedScaleFlow: Identifiable {
    case clinical(scale: ClinicalScale, savedResults: [SavedScaleResultSnapshot])
    case mmse(test: MMSETest)

    var id: String {
        switch self {
        case .clinical(let scale, _):
            "clinical-\(scale.id)"
        case .mmse(let test):
            "mmse-\(test.id)"
        }
    }
}

#Preview {
    NavigationStack {
        ScalesListView(
            patientID: UUID(),
            patientName: "Ana García"
        )
    }
}
