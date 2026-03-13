//
//  ScaleIntroView.swift
//  Ars Medica Digitalis
//
//  Pantalla inicial de una escala antes de comenzar la sesión.
//

import SwiftUI

struct ScaleIntroView: View {

    let scale: ClinicalScale
    let patientID: UUID
    let patientName: String
    let savedResults: [SavedScaleResultSnapshot]

    @State private var route: ScaleIntroRoute? = nil
    @State private var showFullHistory: Bool = false
    private static let historyVisibleLimit: Int = 5
    @Namespace private var glassNamespace

    init(
        scale: ClinicalScale,
        patientID: UUID,
        patientName: String,
        savedResults: [SavedScaleResultSnapshot] = []
    ) {
        self.scale = scale
        self.patientID = patientID
        self.patientName = patientName
        self.savedResults = savedResults
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
                                .accessibilityIdentifier("scale.history.toggle")
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
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            beginButton
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
                .glassEffect(.regular)
        }
        .navigationTitle(scale.id)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $route) { route in
            destination(for: route)
        }
    }

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

            Text(scale.name)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private var descriptionSection: some View {
        Text(scale.description)
            .font(.body)
            .foregroundStyle(.secondary)
            .lineSpacing(4)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 500, alignment: .leading)
    }

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

                summaryRow(label: "Preguntas", value: "\(scale.items.count)")
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

    private func lastResultButton(_ result: SavedScaleResultSnapshot) -> some View {
        let interpretation = scale.scoring.interpretation(for: result.totalScore)
        let ringColor = Color.clinicalRingColor(
            named: interpretation?.color ?? "",
            severity: result.severity
        )

        return Button {
            route = .savedResult(result.id)
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Label("Último resultado", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(ringColor)
                        .frame(width: 10, height: 10)

                    Text(interpretation?.label ?? result.severity.capitalized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text("Score \(result.totalScore)/\(scale.maximumScore)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            .glassEffect(.regular.tint(ringColor.opacity(0.16)).interactive(), in: .rect(cornerRadius: AppCornerRadius.sm))
            .glassEffectID("result-\(result.id.uuidString)", in: glassNamespace)
        }
        .buttonStyle(.plain)
    }

    private func resultButton(_ result: SavedScaleResultSnapshot, isLatest: Bool) -> some View {
        let interpretation = scale.scoring.interpretation(for: result.totalScore)
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

                    Text("Score \(result.totalScore)/\(scale.maximumScore)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            .glassEffect(.regular.tint(ringColor.opacity(0.16)).interactive(), in: .rect(cornerRadius: AppCornerRadius.sm))
            .glassEffectID("result-\(result.id.uuidString)", in: glassNamespace)
        }
        .buttonStyle(.plain)
    }

    private var beginButton: some View {
        Button {
            route = .questionnaire
        } label: {
            Text("Comenzar evaluación")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .accessibilityLabel("Comenzar evaluación \(scale.name)")
        .accessibilityIdentifier("scale.intro.begin")
    }

    @ViewBuilder
    private func destination(for route: ScaleIntroRoute) -> some View {
        switch route {
        case .questionnaire:
            ScaleQuestionView(
                viewModel: ScaleSessionViewModel(
                    scale: scale,
                    patientID: patientID
                )
            )

        case .savedResult(let resultID):
            if let result = savedResults.first(where: { $0.id == resultID }) {
                ScaleSavedResultView(
                    scale: scale,
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

    private var estimatedDurationMinutes: Int {
        max(2, Int(ceil(Double(scale.items.count) * 0.3)))
    }

    private var latestResult: SavedScaleResultSnapshot? {
        savedResults.first
    }

    private var sortedResults: [SavedScaleResultSnapshot] {
        savedResults.sorted { $0.date > $1.date }
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
        return historySummaryText(for: latestResult)
    }

    private func historySummaryText(for result: SavedScaleResultSnapshot) -> String {
        let interpretation = scale.scoring.interpretation(for: result.totalScore)?.label
            ?? result.severity.capitalized
        return "\(interpretation) · Score \(result.totalScore)"
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

private enum ScaleIntroRoute: Identifiable, Hashable {
    case questionnaire
    case savedResult(UUID)

    var id: String {
        switch self {
        case .questionnaire:
            "questionnaire"
        case .savedResult(let resultID):
            "savedResult-\(resultID.uuidString)"
        }
    }
}

#Preview {
    NavigationStack {
        ScaleIntroView(
            scale: ClinicalScale(
                id: "BDI-II",
                name: "Inventario de Depresión de Beck II",
                description: "Escala breve para valorar síntomas depresivos.",
                timeframe: ScaleTimeframe(label: "Últimas dos semanas", value: 14, unit: "days"),
                items: [
                    ScaleItem(
                        id: 1,
                        title: "Tristeza",
                        options: [
                            ScaleOption(text: "No me siento triste", score: 0),
                            ScaleOption(text: "Me siento triste", score: 1),
                        ]
                    ),
                ],
                scoring: ScaleScoring(
                    ranges: [
                        ScoreRange(min: 0, max: 13, label: "Depresión mínima", severity: "minimal", color: "green")
                    ]
                )
            ),
            patientID: UUID(),
            patientName: "Ana García",
            savedResults: []
        )
    }
}

