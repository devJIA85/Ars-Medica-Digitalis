//
//  ScaleResultPersistenceService.swift
//  Ars Medica Digitalis
//
//  Persistencia de resultados de escalas clínicas en SwiftData.
//

import Foundation
import SwiftData

enum ScaleResultPersistenceService {

    @discardableResult
    @MainActor
    static func save(
        _ result: ScaleComputedResult,
        in context: ModelContext
    ) throws -> PatientScaleResult {
        let persistedResult = PatientScaleResult(
            patientID: result.patientID,
            scaleID: result.scaleID,
            date: result.date,
            totalScore: result.totalScore,
            severity: result.severity,
            answers: result.answers
        )

        context.insert(persistedResult)
        try context.save()
        return persistedResult
    }
}
