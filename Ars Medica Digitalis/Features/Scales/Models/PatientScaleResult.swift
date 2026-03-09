//
//  PatientScaleResult.swift
//  Ars Medica Digitalis
//
//  Resultado persistido de una aplicación de escala clínica por paciente.
//

import Foundation
import SwiftData

@Model
final class PatientScaleResult {

    var id: UUID = UUID()
    var patientID: UUID = UUID()
    var scaleID: String = ""
    var date: Date = Date()
    var totalScore: Int = 0
    var severity: String = ""
    var answers: [ScaleAnswer] = []

    init(
        id: UUID = UUID(),
        patientID: UUID,
        scaleID: String,
        date: Date = Date(),
        totalScore: Int,
        severity: String,
        answers: [ScaleAnswer]
    ) {
        self.id = id
        self.patientID = patientID
        self.scaleID = scaleID
        self.date = date
        self.totalScore = totalScore
        self.severity = severity
        self.answers = answers
    }
}
