//
//  AnthropometricRecord.swift
//  Ars Medica Digitalis
//
//  Registro histórico de mediciones antropométricas.
//  Cada vez que el profesional actualiza peso/altura/cintura
//  se crea un snapshot inmutable para trazar la evolución temporal
//  mediante Swift Charts. El dato "actual" sigue viviendo en Patient
//  (retrocompatibilidad y acceso directo sin query).
//

import Foundation
import SwiftData

@Model
final class AnthropometricRecord {

    var id: UUID = UUID()

    /// Fecha en que se tomaron las mediciones
    var recordDate: Date = Date()

    /// Peso en kilogramos al momento del registro
    var weightKg: Double = 0

    /// Altura en centímetros al momento del registro
    var heightCm: Double = 0

    /// Perímetro de cintura en centímetros
    var waistCm: Double = 0

    var createdAt: Date = Date()

    // Relación opcional — requisito CloudKit
    var patient: Patient? = nil

    // MARK: - Computed

    /// IMC calculado a partir de los valores del registro.
    /// No se persiste porque depende de peso y altura que ya están guardados.
    var bmi: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        recordDate: Date = Date(),
        weightKg: Double = 0,
        heightCm: Double = 0,
        waistCm: Double = 0,
        createdAt: Date = Date(),
        patient: Patient? = nil
    ) {
        self.id = id
        self.recordDate = recordDate
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.waistCm = waistCm
        self.createdAt = createdAt
        self.patient = patient
    }
}
