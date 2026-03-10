//
//  MMSEStore.swift
//  Ars Medica Digitalis
//
//  Estado observable de la evaluación MMSE y reglas de score/progreso.
//

import Foundation
import Observation

@Observable
@MainActor
final class MMSEStore {
    /// Test cargado desde JSON. Se mantiene inmutable para preservar consistencia.
    private(set) var test: MMSETest

    /// Respuestas por `item.id` (true = correcto, false = incorrecto).
    var responses: [String: Bool] = [:]

    /// Índice de la sección activa para flujo secuencial.
    private(set) var currentSectionIndex: Int = 0

    init(test: MMSETest) {
        self.test = test
    }

    /// Score total calculado únicamente con los ítems evaluables respondidos como correctos.
    var totalScore: Int {
        test.sections.reduce(0) { partialResult, section in
            partialResult + score(for: section)
        }
    }

    /// Score por sección usando la estructura dinámica del JSON.
    var sectionScores: [String: Int] {
        Dictionary(uniqueKeysWithValues: test.sections.map { section in
            (section.id, score(for: section))
        })
    }

    /// Progreso global de completitud de ítems evaluables (0...1).
    var progress: Double {
        guard totalScorableItems > 0 else { return 0 }
        return Double(responses.count) / Double(totalScorableItems)
    }

    /// Cantidad de ítems evaluables respondidos.
    var answeredScorableItems: Int {
        responses.count
    }

    /// Total de ítems evaluables definidos por JSON.
    var totalScorableItems: Int {
        test.scorableItems.count
    }

    /// Bandera de finalización completa del assessment.
    var isComplete: Bool {
        totalScorableItems > 0 && answeredScorableItems == totalScorableItems
    }

    /// Sección actual en pantalla según el flujo secuencial.
    var currentSection: MMSESection? {
        guard test.sections.indices.contains(currentSectionIndex) else { return nil }
        return test.sections[currentSectionIndex]
    }

    /// Secciones visibles hasta la sección actual para dar contexto clínico progresivo.
    var visibleSections: [MMSESection] {
        guard !test.sections.isEmpty else { return [] }
        return Array(test.sections.prefix(currentSectionIndex + 1))
    }

    /// Interpretación clínica basada en el score y rangos del JSON.
    var currentInterpretation: MMSEScoringRange? {
        test.scoring.interpretation(for: totalScore)
    }

    /// Habilita avanzar sólo cuando la sección actual está completa.
    var canAdvanceToNextSection: Bool {
        guard let currentSection else { return false }
        return isSectionComplete(currentSection)
    }

    var hasNextSection: Bool {
        currentSectionIndex < test.sections.count - 1
    }

    var hasPreviousSection: Bool {
        currentSectionIndex > 0
    }

    /// Guarda/actualiza respuesta para un ítem evaluable.
    func setResponse(for item: MMSEItem, isCorrect: Bool) {
        guard item.isScorable else { return }
        responses[item.id] = isCorrect
    }

    /// Respuesta actual para un item, usada por la UI para reflejar selección.
    func response(for itemID: String) -> Bool? {
        responses[itemID]
    }

    /// Score de una sección específica.
    func score(for section: MMSESection) -> Int {
        section.scorableItems.reduce(0) { partialResult, item in
            guard responses[item.id] == true else { return partialResult }
            return partialResult + item.effectiveMaxScore
        }
    }

    /// Progreso interno por sección para feedback granular en la UI.
    func progress(for section: MMSESection) -> Double {
        let total = section.scorableItems.count
        guard total > 0 else { return 1 }

        let answered = section.scorableItems.reduce(0) { partialResult, item in
            partialResult + (responses[item.id] != nil ? 1 : 0)
        }
        return Double(answered) / Double(total)
    }

    /// Una sección está completa cuando todos sus ítems evaluables fueron respondidos.
    func isSectionComplete(_ section: MMSESection) -> Bool {
        section.scorableItems.allSatisfy { responses[$0.id] != nil }
    }

    /// Avanza secuencialmente evitando saltos que rompan el flujo clínico.
    func goToNextSection() {
        guard hasNextSection, canAdvanceToNextSection else { return }
        currentSectionIndex += 1
    }

    /// Permite retroceder para corregir respuestas.
    func goToPreviousSection() {
        guard hasPreviousSection else { return }
        currentSectionIndex -= 1
    }

    /// Proyección estable de respuestas MMSE al modelo persistible de resultados.
    /// Se usa un índice correlativo para mantener compatibilidad con `ScaleAnswer`.
    func persistedAnswers() -> [ScaleAnswer] {
        test.scorableItems.enumerated().compactMap { index, item in
            guard let isCorrect = responses[item.id] else { return nil }

            return ScaleAnswer(
                itemID: index + 1,
                selectedScore: isCorrect ? item.effectiveMaxScore : 0,
                selectedOptionID: nil,
                selectedText: item.id
            )
        }
    }
}
