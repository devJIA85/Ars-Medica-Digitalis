//
//  ScaleSessionViewModel.swift
//  Ars Medica Digitalis
//
//  Estado y reglas de una sesión de aplicación de escala clínica.
//

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ScaleSessionViewModel {

    enum NavigationDirection {
        case forward
        case backward
    }

    enum SessionError: Error, LocalizedError {
        case unfinishedQuestionnaire
        case resultUnavailable

        var errorDescription: String? {
            switch self {
            case .unfinishedQuestionnaire:
                "Completá todas las preguntas antes de finalizar la escala."
            case .resultUnavailable:
                "No hay un resultado calculado para guardar."
            }
        }
    }

    let patientID: UUID
    let scale: ClinicalScale

    private(set) var currentQuestionIndex: Int = 0
    private(set) var selectedOptionIDByItemID: [Int: UUID] = [:]
    private(set) var answersByItemID: [Int: Int] = [:]
    private(set) var computedResult: ScaleComputedResult? = nil
    private(set) var savedResultID: UUID? = nil
    private(set) var navigationDirection: NavigationDirection = .forward

    init(scale: ClinicalScale, patientID: UUID) {
        self.scale = scale
        self.patientID = patientID
    }

    var totalQuestions: Int {
        scale.items.count
    }

    var currentItem: ScaleItem? {
        guard scale.items.indices.contains(currentQuestionIndex) else { return nil }
        return scale.items[currentQuestionIndex]
    }

    var currentQuestionLabel: String {
        guard totalQuestions > 0 else { return "Pregunta 0 de 0" }
        return "Pregunta \(currentQuestionIndex + 1) de \(totalQuestions)"
    }

    var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(totalQuestions)
    }

    var isFirstQuestion: Bool {
        currentQuestionIndex == 0
    }

    var isLastQuestion: Bool {
        currentQuestionIndex == max(totalQuestions - 1, 0)
    }

    var selectedScoreForCurrentQuestion: Int? {
        guard let currentItem else { return nil }
        return answersByItemID[currentItem.id]
    }

    var selectedOptionIDForCurrentQuestion: UUID? {
        guard let currentItem else { return nil }
        return selectedOptionIDByItemID[currentItem.id]
    }

    var canMoveForward: Bool {
        selectedOptionIDForCurrentQuestion != nil
    }

    var isComplete: Bool {
        scale.items.allSatisfy { selectedOptionIDByItemID[$0.id] != nil }
    }

    func selectAnswer(itemID: Int, optionID: UUID, score: Int) {
        selectedOptionIDByItemID[itemID] = optionID
        answersByItemID[itemID] = score
    }

    func nextQuestion() {
        guard canMoveForward else { return }
        guard currentQuestionIndex < totalQuestions - 1 else { return }
        navigationDirection = .forward
        currentQuestionIndex += 1
    }

    func previousQuestion() {
        guard currentQuestionIndex > 0 else { return }
        navigationDirection = .backward
        currentQuestionIndex -= 1
    }

    func calculateScore() -> Int {
        scale.items.reduce(0) { partialResult, item in
            partialResult + (answersByItemID[item.id] ?? 0)
        }
    }

    @discardableResult
    func finishScale() throws -> ScaleComputedResult {
        guard isComplete else {
            throw SessionError.unfinishedQuestionnaire
        }

        let totalScore = calculateScore()
        let interpretedRange = scale.scoring.interpretation(for: totalScore)
        let interpretationLabel = interpretedRange?.label ?? "Sin interpretación"
        let severity = interpretedRange?.severity ?? "unknown"
        let color = interpretedRange?.color ?? "gray"
        let answers: [ScaleAnswer] = scale.items.compactMap { item in
            guard let selectedScore = answersByItemID[item.id] else { return nil }
            let selectedOptionID = selectedOptionIDByItemID[item.id]
            let selectedOptionText = item.options
                .first(where: { $0.id == selectedOptionID })?
                .text

            return ScaleAnswer(
                itemID: item.id,
                selectedScore: selectedScore,
                selectedOptionID: selectedOptionID,
                selectedText: selectedOptionText
            )
        }

        let result = ScaleComputedResult(
            patientID: patientID,
            scaleID: scale.id,
            date: Date(),
            totalScore: totalScore,
            maximumScore: scale.maximumScore,
            severity: severity,
            interpretationLabel: interpretationLabel,
            color: color,
            answers: answers
        )

        computedResult = result
        return result
    }

    @discardableResult
    func saveResult(in context: ModelContext) throws -> PatientScaleResult {
        guard let computedResult else {
            throw SessionError.resultUnavailable
        }

        if let savedResultID {
            let id = savedResultID
            let descriptor = FetchDescriptor<PatientScaleResult>(
                predicate: #Predicate<PatientScaleResult> { result in
                    result.id == id
                }
            )

            if let existing = try context.fetch(descriptor).first {
                return existing
            }
        }

        let saved = try ScaleResultPersistenceService.save(computedResult, in: context)
        savedResultID = saved.id
        return saved
    }
}
