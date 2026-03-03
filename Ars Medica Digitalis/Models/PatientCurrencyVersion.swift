//
//  PatientCurrencyVersion.swift
//  Ars Medica Digitalis
//
//  Historial de moneda vigente por paciente.
//  Permite resolver la moneda correcta según la fecha de la sesión.
//

import Foundation
import SwiftData

@Model
final class PatientCurrencyVersion {

    var id: UUID = UUID()

    /// Código ISO 4217 vigente desde effectiveFrom.
    var currencyCode: String = ""

    /// Fecha de inicio de vigencia de la moneda del paciente.
    var effectiveFrom: Date = Date()

    // Trazabilidad administrativa
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Flujo financiero de moneda:
    // Patient -> PatientCurrencyVersion.
    // La sesión consultará este historial más adelante para resolver
    // la moneda aplicable sin reescribir datos clínicos existentes.
    var patient: Patient? = nil

    init(
        id: UUID = UUID(),
        currencyCode: String = "",
        effectiveFrom: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        patient: Patient? = nil
    ) {
        self.id = id
        self.currencyCode = currencyCode
        self.effectiveFrom = effectiveFrom
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.patient = patient
    }
}
