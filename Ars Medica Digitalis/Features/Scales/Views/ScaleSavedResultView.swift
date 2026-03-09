//
//  ScaleSavedResultView.swift
//  Ars Medica Digitalis
//
//  Detalle de una administración guardada con resultado y respuestas.
//

import SwiftUI

struct ScaleSavedResultView: View {

    let scale: ClinicalScale
    let patientName: String
    let result: PatientScaleResult

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionGap) {
                summaryCard

                VStack(spacing: AppSpacing.md) {
                    ForEach(answeredItems) { answered in
                        answerCard(answered)
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
        .navigationTitle("Resultado guardado")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        CardContainer(style: .elevated) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Paciente: \(patientName)")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(dateFormatter.string(from: result.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Text("Score: \(result.totalScore) / \(scale.maximumScore)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(interpretationLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Severidad: \(result.severity)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCardEntrance()
    }

    private func answerCard(_ answered: AnsweredItem) -> some View {
        CardContainer(style: .flat) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Pregunta \(answered.itemID)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(answered.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Divider()

                Text(answered.answerText)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("Puntaje: \(answered.score)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCardEntrance()
    }

    private var interpretationLabel: String {
        scale.scoring.interpretation(for: result.totalScore)?.label ?? "Interpretación no disponible"
    }

    private var answeredItems: [AnsweredItem] {
        scale.items.compactMap { item in
            guard let answer = result.answers.first(where: { $0.itemID == item.id }) else { return nil }
            return AnsweredItem(
                itemID: item.id,
                title: item.title,
                answerText: answerText(for: item, answer: answer),
                score: answer.selectedScore
            )
        }
    }

    private func answerText(for item: ScaleItem, answer: ScaleAnswer) -> String {
        if let selectedText = answer.selectedText, selectedText.isEmpty == false {
            return selectedText
        }

        if let selectedOptionID = answer.selectedOptionID,
           let option = item.options.first(where: { $0.id == selectedOptionID }) {
            return option.text
        }

        if let option = item.options.first(where: { $0.score == answer.selectedScore }) {
            return option.text
        }

        return "Respuesta no disponible"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

private struct AnsweredItem: Identifiable {
    let itemID: Int
    let title: String
    let answerText: String
    let score: Int

    var id: Int { itemID }
}
