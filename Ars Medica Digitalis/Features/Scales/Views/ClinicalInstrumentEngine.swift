//
//  ClinicalInstrumentEngine.swift
//  Ars Medica Digitalis
//
//  Motor para consultar instrumentos clínicos (escalas) persistidos en SwiftData.
//

import Foundation
import SwiftData

struct ClinicalInstrumentEngine: Sendable {

    /// Devuelve el último resultado guardado para una escala específica de un paciente.
    /// - Parameters:
    ///   - patientID: Identificador del paciente
    ///   - scaleID: Identificador de la escala (por ejemplo, "BDI-II")
    ///   - context: ModelContext de SwiftData
    /// - Returns: Snapshot del último resultado o `nil` si no hay registros
    @MainActor
    func latestResult(
        for patientID: UUID,
        scaleID: String,
        in context: ModelContext
    ) -> SavedScaleResultSnapshot? {
        let descriptor = FetchDescriptor<PatientScaleResult>(
            predicate: #Predicate { $0.patientID == patientID && $0.scaleID == scaleID },
            sortBy: [
                SortDescriptor(\.date, order: .reverse)
            ]
        )
        if let result = try? context.fetch(descriptor).first {
            return SavedScaleResultSnapshot(result: result)
        }
        return nil
    }
}
