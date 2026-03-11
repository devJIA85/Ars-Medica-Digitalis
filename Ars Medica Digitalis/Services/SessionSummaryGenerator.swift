//
//  SessionSummaryGenerator.swift
//  Ars Medica Digitalis
//
//  Generador de resumen clínico usando Foundation Models (Apple Intelligence).
//  El procesamiento corre en el dispositivo y no usa APIs externas.
//

import Foundation
import FoundationModels

@available(iOS 26.0, *)
struct SessionSummaryGenerator: Sendable {

    enum GeneratorError: LocalizedError {
        case emptyClinicalNotes
        case modelUnavailable(SystemLanguageModel.Availability)
        case emptyModelResponse

        var errorDescription: String? {
            switch self {
            case .emptyClinicalNotes:
                return "Las notas clínicas están vacías."
            case .modelUnavailable(let availability):
                switch availability {
                case .available:
                    return "El modelo no está disponible temporalmente."
                case .unavailable(let reason):
                    switch reason {
                    case .deviceNotEligible:
                        return "Este dispositivo no es elegible para Apple Intelligence."
                    case .appleIntelligenceNotEnabled:
                        return "Apple Intelligence está desactivado en el dispositivo."
                    case .modelNotReady:
                        return "El modelo local aún no está listo. Intentá nuevamente en unos minutos."
                    @unknown default:
                        return "El modelo no está disponible por una razón desconocida."
                    }
                }
            case .emptyModelResponse:
                return "No se pudo generar un resumen clínico válido."
            }
        }
    }

    private let model: SystemLanguageModel

    init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    /// Ejecuta una inferencia local para resumir notas y plan terapéutico.
    /// Se utiliza un prompt estructurado para forzar tono clínico y límite breve.
    func generateSummary(clinicalNotes: String, treatmentPlan: String) async throws -> String {
        let notes = clinicalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = treatmentPlan.trimmingCharacters(in: .whitespacesAndNewlines)

        guard notes.isEmpty == false else {
            throw GeneratorError.emptyClinicalNotes
        }

        guard model.isAvailable else {
            throw GeneratorError.modelUnavailable(model.availability)
        }

        // Nueva sesión por solicitud para evitar contaminación de contexto
        // entre distintas consultas clínicas.
        // Además fijamos instrucciones globales para bloquear el idioma en español.
        let session = LanguageModelSession(
            model: model,
            instructions: """
            Responde exclusivamente en español.
            No uses inglés ni mezcles idiomas.
            Mantén un tono clínico profesional y conciso.
            """
        )

        let prompt = """
        Eres un asistente clínico que ayuda a un profesional de la salud a resumir una sesión.

        Analiza el siguiente contenido.

        Notas clínicas:
        \(notes)

        Plan terapéutico:
        \(plan)

        Genera un resumen clínico breve que incluya:

        • síntomas principales
        • hallazgos relevantes
        • decisión terapéutica
        • plan de seguimiento

        Usa tono clínico profesional.
        Responde únicamente en español.
        No agregues títulos ni viñetas.
        No limites la longitud del resumen.
        Asegurate de finalizar el texto con una idea completa.
        """

        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(
                sampling: .greedy,
                temperature: 0.2
            )
        )

        let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard summary.isEmpty == false else {
            throw GeneratorError.emptyModelResponse
        }

        return summary
    }
}
