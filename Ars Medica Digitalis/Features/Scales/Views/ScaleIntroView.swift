//
//  ScaleIntroView.swift
//  Ars Medica Digitalis
//
//  Pantalla inicial de una escala antes de comenzar la sesión.
//

import SwiftUI
import SwiftData

struct ScaleIntroView: View {

    @Environment(\.dismiss) private var dismiss

    let scale: ClinicalScale
    let patientID: UUID
    let patientName: String
    let onSessionSaved: () -> Void

    @Query private var savedResults: [PatientScaleResult]

    init(
        scale: ClinicalScale,
        patientID: UUID,
        patientName: String,
        onSessionSaved: @escaping () -> Void = {}
    ) {
        self.scale = scale
        self.patientID = patientID
        self.patientName = patientName
        self.onSessionSaved = onSessionSaved

        let patientIdentifier = patientID
        let scaleIdentifier = scale.id
        _savedResults = Query(
            filter: #Predicate<PatientScaleResult> { result in
                result.patientID == patientIdentifier && result.scaleID == scaleIdentifier
            },
            sort: [SortDescriptor(\PatientScaleResult.date, order: .reverse)]
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionGap) {
                introCard
                beginButton

                if savedResults.isEmpty == false {
                    historySection
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .themedBackground()
        .navigationTitle(scale.id)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introCard: some View {
        CardContainer(style: .elevated) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(scale.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(scale.description)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Divider()

                detailRow(
                    title: "Paciente",
                    value: patientName,
                    systemImage: "person.text.rectangle"
                )
                detailRow(
                    title: "Última administración",
                    value: latestAdministrationText,
                    systemImage: "calendar"
                )
                detailRow(
                    title: "Último resultado",
                    value: latestResultSummaryText,
                    systemImage: "chart.bar.doc.horizontal"
                )
                detailRow(
                    title: "Duración estimada",
                    value: "\(estimatedDurationMinutes) minutos",
                    systemImage: "timer"
                )
                detailRow(
                    title: "Cantidad de preguntas",
                    value: "\(scale.items.count)",
                    systemImage: "list.number"
                )
            }
        }
        .glassCardEntrance()
    }

    private var beginButton: some View {
        NavigationLink {
            ScaleQuestionView(
                viewModel: ScaleSessionViewModel(
                    scale: scale,
                    patientID: patientID
                ),
                onSessionSaved: {
                    dismiss()
                    DispatchQueue.main.async {
                        onSessionSaved()
                    }
                }
            )
        } label: {
            Text("Comenzar")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel("Comenzar \(scale.name)")
    }

    private var historySection: some View {
        CardContainer(style: .flat) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Historial de administraciones")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Últimos resultados guardados para esta escala.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(spacing: AppSpacing.sm) {
                    ForEach(savedResults.prefix(12), id: \.id) { result in
                        historyRow(result: result)
                    }
                }
            }
        }
        .glassCardEntrance()
    }

    private func historyRow(result: PatientScaleResult) -> some View {
        NavigationLink {
            ScaleSavedResultView(
                scale: scale,
                patientName: patientName,
                result: result
            )
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(latestAdministrationFormatter.string(from: result.date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(historySummaryText(for: result))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: AppSpacing.md)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detailRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.md)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }

    private var estimatedDurationMinutes: Int {
        max(2, Int(ceil(Double(scale.items.count) * 0.3)))
    }

    private var latestResult: PatientScaleResult? {
        savedResults.first
    }

    private var latestAdministrationText: String {
        guard let latestResult else { return "Sin registros" }
        return latestAdministrationFormatter.string(from: latestResult.date)
    }

    private var latestResultSummaryText: String {
        guard let latestResult else { return "Sin registros" }
        return historySummaryText(for: latestResult)
    }

    private func historySummaryText(for result: PatientScaleResult) -> String {
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
            patientName: "Ana García"
        )
    }
}
