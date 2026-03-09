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
    @State private var loadErrorMessage: String? = nil
    @State private var isLoading: Bool = false

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
                } else if scales.isEmpty {
                    ContentUnavailableView(
                        "Sin escalas disponibles",
                        systemImage: "list.bullet.clipboard",
                        description: Text(loadErrorMessage ?? "No se encontraron escalas válidas.")
                    )
                } else {
                    VStack(spacing: AppSpacing.md) {
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
        .themedBackground()
        .navigationTitle("Escalas")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadScales()
        }
        .refreshable {
            await loadScales()
        }
    }

    private var headerCard: some View {
        CardContainer(style: .flat) {
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
        .glassCardEntrance()
    }

    private func scaleRow(_ scale: ClinicalScale) -> some View {
        NavigationLink {
            ScaleIntroView(
                scale: scale,
                patientID: patientID,
                patientName: patientName,
                onSessionSaved: {
                    dismiss()
                }
            )
        } label: {
            CardContainer(style: .flat) {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "waveform.path.ecg")
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
            .glassCardEntrance()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(scale.name)
    }

    @MainActor
    private func loadScales() async {
        isLoading = true
        defer { isLoading = false }

        do {
            scales = try ScaleLoader.loadAll()
            loadErrorMessage = nil
        } catch {
            scales = []
            loadErrorMessage = error.localizedDescription
        }
    }

    private func subtitleText(for scale: ClinicalScale) -> String {
        guard let latestResult = latestResultByScaleID[scale.id] else {
            return scale.timeframe.displayLabel
        }

        let interpretation = scale.scoring.interpretation(for: latestResult.totalScore)?.label
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
}

#Preview {
    NavigationStack {
        ScalesListView(
            patientID: UUID(),
            patientName: "Ana García"
        )
    }
}
