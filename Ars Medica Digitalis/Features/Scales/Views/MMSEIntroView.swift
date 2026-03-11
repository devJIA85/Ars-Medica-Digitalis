//
//  MMSEIntroView.swift
//  Ars Medica Digitalis
//
//  Pantalla intermedia de MMSE con resumen y evolución histórica.
//

import SwiftUI
import SwiftData

struct MMSEIntroView: View {
    let test: MMSETest
    let patientID: UUID
    let patientName: String
    let onSessionSaved: () -> Void

    @Query private var savedResults: [PatientScaleResult]

    @State private var route: MMSEIntroRoute? = nil
    @State private var showFullHistory: Bool = false
    @Namespace private var glassNamespace
    private static let historyVisibleLimit: Int = 5

    init(
        test: MMSETest,
        patientID: UUID,
        patientName: String,
        onSessionSaved: @escaping () -> Void = {}
    ) {
        self.test = test
        self.patientID = patientID
        self.patientName = patientName
        self.onSessionSaved = onSessionSaved

        let patientIdentifier = patientID
        let scaleIdentifier = test.id
        _savedResults = Query(
            filter: #Predicate<PatientScaleResult> { result in
                result.patientID == patientIdentifier && result.scaleID == scaleIdentifier
            },
            sort: [SortDescriptor(\PatientScaleResult.date, order: .reverse)]
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                heroTitle

                descriptionSection

                summaryPanel

                if !sortedResults.isEmpty {
                    GlassEffectContainer(spacing: 20) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Historial de resultados")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            ForEach(Array(visibleResults.enumerated()), id: \.element.id) { index, result in
                                resultButton(result, isLatest: index == 0)
                            }

                            if sortedResults.count > Self.historyVisibleLimit {
                                Button {
                                    withAnimation(.smooth(duration: 0.25)) {
                                        showFullHistory.toggle()
                                    }
                                } label: {
                                    let remaining = max(0, sortedResults.count - Self.historyVisibleLimit)
                                    Text(showFullHistory ? "Ver menos" : "Ver más\(remaining > 0 ? " (\(remaining))" : "")")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.tint)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, AppSpacing.xs)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("mmse.history.toggle")
                            }
                        }
                        .animation(.smooth(duration: 0.28), value: showFullHistory)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            beginButton
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
                .glassEffect(.regular)
        }
        .navigationTitle(test.id)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $route) { route in
            destination(for: route)
        }
    }

    /// Encabezado visual equivalente al flujo BDI para mantener consistencia de producto.
    /// Se usa liquid glass en el ícono para igualar lenguaje visual.
    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ZStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .symbolColorRenderingMode(.gradient)
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)
            }
            .glassEffect(.regular.tint(Color.accentColor.opacity(0.18)).interactive(), in: .circle)
            .accessibilityHidden(true)

            Text(test.name)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private var descriptionSection: some View {
        Text(test.description)
            .font(.body)
            .foregroundStyle(.secondary)
            .lineSpacing(4)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 500, alignment: .leading)
    }

    /// Panel de resumen con liquid glass para reflejar exactamente la jerarquía de BDI.
    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow(label: "Paciente", value: patientName)

            Divider().padding(.leading, AppSpacing.md)

            summaryRow(label: "Última administración", value: latestAdministrationText)

            Divider().padding(.leading, AppSpacing.md)

            summaryRow(label: "Último resultado", value: latestResultSummaryText)

            Divider().padding(.leading, AppSpacing.md)

            HStack(spacing: 0) {
                summaryRow(label: "Duración", value: "\(estimatedDurationMinutes) min")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 32)

                summaryRow(label: "Preguntas", value: "\(test.scorableItems.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: AppCornerRadius.sm))
    }

    private func summaryRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm + 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func resultButton(_ result: SavedScaleResultSnapshot, isLatest: Bool) -> some View {
        let interpretation = test.scoring.interpretation(for: result.totalScore)
        let ringColor = Color.clinicalRingColor(
            named: interpretation?.color ?? "",
            severity: result.severity
        )

        return Button {
            route = .savedResult(result.id)
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    if isLatest {
                        Label("Último resultado", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                // Fecha de la toma (siempre visible)
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(historyDateFormatter.string(from: result.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Resumen de interpretación y score
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(ringColor)
                        .frame(width: 10, height: 10)

                    Text(interpretation?.label ?? result.severity.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text("Score \(result.totalScore)/\(test.maximumScore)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            .glassEffect(.regular.tint(ringColor.opacity(0.16)).interactive(), in: .rect(cornerRadius: AppCornerRadius.sm))
            .glassEffectID("mmse-result-\(result.id.uuidString)", in: glassNamespace)
        }
        .buttonStyle(.plain)
    }

    private var beginButton: some View {
        Button {
            route = .assessment
        } label: {
            Text("Comenzar evaluación")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .accessibilityIdentifier("mmse.intro.begin")
    }

    @ViewBuilder
    private func destination(for route: MMSEIntroRoute) -> some View {
        switch route {
        case .assessment:
            MMSEAssessmentView(
                patientID: patientID,
                onResultSaved: onSessionSaved
            )
        case .savedResult(let resultID):
            if let result = snapshots.first(where: { $0.id == resultID }) {
                MMSESavedResultView(
                    test: test,
                    patientName: patientName,
                    result: result
                )
            } else {
                ContentUnavailableView(
                    "Resultado no disponible",
                    systemImage: "exclamationmark.triangle",
                    description: Text("No se encontró el resultado seleccionado.")
                )
            }
        }
    }

    @MainActor
    private var snapshots: [SavedScaleResultSnapshot] {
        savedResults.map(SavedScaleResultSnapshot.init)
    }

    private var latestResult: SavedScaleResultSnapshot? {
        sortedResults.first
    }

    private var sortedResults: [SavedScaleResultSnapshot] {
        snapshots.sorted { $0.date > $1.date }
    }

    private var visibleResults: [SavedScaleResultSnapshot] {
        if showFullHistory { return sortedResults }
        return Array(sortedResults.prefix(Self.historyVisibleLimit))
    }

    private var latestAdministrationText: String {
        guard let latestResult else { return "Sin registros" }
        return latestAdministrationFormatter.string(from: latestResult.date)
    }

    private var latestResultSummaryText: String {
        guard let latestResult else { return "Sin registros" }
        let interpretation = test.scoring.interpretation(for: latestResult.totalScore)?.label
            ?? latestResult.severity.capitalized
        return "\(interpretation) · Score \(latestResult.totalScore)"
    }

    private var estimatedDurationMinutes: Int {
        max(5, Int(ceil(Double(test.scorableItems.count) * 0.35)))
    }

    private var latestAdministrationFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    private var historyDateFormatter: DateFormatter { latestAdministrationFormatter }
}

private enum MMSEIntroRoute: Identifiable, Hashable {
    case assessment
    case savedResult(UUID)

    var id: String {
        switch self {
        case .assessment:
            "assessment"
        case .savedResult(let resultID):
            "savedResult-\(resultID.uuidString)"
        }
    }
}

#Preview {
    NavigationStack {
        MMSEIntroView(
            test: MMSETest(
                id: "MMSE",
                domain: "cognition",
                name: "Mini Mental State Examination",
                description: "Prueba breve para cribado cognitivo.",
                timeframe: nil,
                meta: MMSEMeta(maxScore: 30, version: nil, administeredBy: nil),
                sections: [],
                scoring: MMSEScoring(ranges: [])
            ),
            patientID: UUID(),
            patientName: "Ana García"
        )
    }
}
