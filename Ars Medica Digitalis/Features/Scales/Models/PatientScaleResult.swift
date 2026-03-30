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
    @Attribute(originalName: "answers")
    private var answersData: Data = Data()

    var answers: [ScaleAnswer] {
        get {
            guard answersData.isEmpty == false else { return [] }
            return (try? Self.decoder.decode([ScaleAnswer].self, from: answersData)) ?? []
        }
        set {
            answersData = (try? Self.encoder.encode(newValue)) ?? Data()
        }
    }

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
        self.answersData = (try? Self.encoder.encode(answers)) ?? Data()
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
}

struct SavedScaleResultSnapshot: Identifiable, Equatable, Hashable {
    let id: UUID
    let patientID: UUID
    let scaleID: String
    let date: Date
    let totalScore: Int
    let severity: String
    let answers: [ScaleAnswer]

    init(result: PatientScaleResult) {
        id = result.id
        patientID = result.patientID
        scaleID = result.scaleID
        date = result.date
        totalScore = result.totalScore
        severity = result.severity
        answers = result.answers
    }
}
