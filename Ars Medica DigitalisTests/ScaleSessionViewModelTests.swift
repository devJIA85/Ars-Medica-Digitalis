//
//  ScaleSessionViewModelTests.swift
//  Ars Medica DigitalisTests
//
//  Evita regresiones de selección doble en ítems con opciones
//  distintas que comparten el mismo score (ej. BDI-II 16 y 18).
//

import Foundation
import Testing
@testable import Ars_Medica_Digitalis

struct ScaleSessionViewModelTests {

    @MainActor
    @Test
    func selectingDuplicateScoreOptionsKeepsSingleSelectedOption() {
        let optionIncrease = ScaleOption(
            id: UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!,
            sourceID: "16-1-increase",
            text: "Duermo un poco más que lo habitual",
            score: 1,
            variant: .increase
        )
        let optionDecrease = ScaleOption(
            id: UUID(uuidString: "A0000000-0000-4000-8000-000000000002")!,
            sourceID: "16-1-decrease",
            text: "Duermo un poco menos que lo habitual",
            score: 1,
            variant: .decrease
        )
        let optionHigh = ScaleOption(
            id: UUID(uuidString: "A0000000-0000-4000-8000-000000000003")!,
            sourceID: "16-2-increase",
            text: "Duermo mucho más que lo habitual",
            score: 2,
            variant: .increase
        )

        let item = ScaleItem(id: 16, title: "Cambios en el Patrón de Sueño", options: [
            optionIncrease,
            optionDecrease,
            optionHigh,
        ])
        let viewModel = ScaleSessionViewModel(
            scale: makeScale(items: [item]),
            patientID: UUID()
        )

        viewModel.selectAnswer(itemID: item.id, optionID: optionIncrease.id, score: optionIncrease.score)
        #expect(viewModel.selectedOptionIDForCurrentQuestion == optionIncrease.id)
        #expect(viewModel.selectedScoreForCurrentQuestion == 1)

        viewModel.selectAnswer(itemID: item.id, optionID: optionDecrease.id, score: optionDecrease.score)
        #expect(viewModel.selectedOptionIDForCurrentQuestion == optionDecrease.id)
        #expect(viewModel.selectedScoreForCurrentQuestion == 1)
        #expect(viewModel.canMoveForward)
    }

    @MainActor
    @Test
    func finishScaleUsesSelectedOptionScoreWhenDuplicateScoresExist() throws {
        let sleepIncrease = ScaleOption(
            id: UUID(uuidString: "B0000000-0000-4000-8000-000000000001")!,
            sourceID: "16-1-increase",
            text: "Duermo un poco más que lo habitual",
            score: 1,
            variant: .increase
        )
        let sleepDecrease = ScaleOption(
            id: UUID(uuidString: "B0000000-0000-4000-8000-000000000002")!,
            sourceID: "16-1-decrease",
            text: "Duermo un poco menos que lo habitual",
            score: 1,
            variant: .decrease
        )
        let moodZero = ScaleOption(
            id: UUID(uuidString: "B0000000-0000-4000-8000-000000000003")!,
            sourceID: "1-0",
            text: "No me siento triste",
            score: 0
        )
        let moodOne = ScaleOption(
            id: UUID(uuidString: "B0000000-0000-4000-8000-000000000004")!,
            sourceID: "1-1",
            text: "Me siento triste",
            score: 1
        )

        let items = [
            ScaleItem(id: 16, title: "Cambios en el Patrón de Sueño", options: [sleepIncrease, sleepDecrease]),
            ScaleItem(id: 1, title: "Tristeza", options: [moodZero, moodOne]),
        ]
        let viewModel = ScaleSessionViewModel(
            scale: makeScale(items: items),
            patientID: UUID()
        )

        viewModel.selectAnswer(itemID: 16, optionID: sleepDecrease.id, score: sleepDecrease.score)
        viewModel.selectAnswer(itemID: 1, optionID: moodOne.id, score: moodOne.score)

        let result = try viewModel.finishScale()
        let sleepAnswer = result.answers.first(where: { $0.itemID == 16 })
        let moodAnswer = result.answers.first(where: { $0.itemID == 1 })

        #expect(result.totalScore == 2)
        #expect(sleepAnswer?.selectedScore == 1)
        #expect(sleepAnswer?.selectedOptionID == sleepDecrease.id)
        #expect(sleepAnswer?.selectedText == sleepDecrease.text)
        #expect(moodAnswer?.selectedScore == 1)
        #expect(moodAnswer?.selectedOptionID == moodOne.id)
        #expect(moodAnswer?.selectedText == moodOne.text)
    }

    private func makeScale(items: [ScaleItem]) -> ClinicalScale {
        ClinicalScale(
            id: "BDI-II",
            domain: "depression",
            name: "Inventario de Depresión de Beck",
            description: "Escala clínica de ejemplo para tests.",
            timeframe: ScaleTimeframe(label: "Últimas dos semanas", value: 14, unit: "days"),
            meta: ScaleMeta(itemsCount: items.count, maxScore: 63, version: "1.0.0"),
            items: items,
            scoring: ScaleScoring(
                ranges: [
                    ScoreRange(min: 0, max: 63, label: "Rango Test", severity: "minimal", color: "green"),
                ]
            )
        )
    }
}
