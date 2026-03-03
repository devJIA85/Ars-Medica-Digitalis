//
//  PatientSessionDefaultPrice.swift
//  Ars Medica Digitalis
//
//  Precio por defecto a nivel paciente para un tipo de sesión facturable.
//  No reemplaza al precio versionado del catálogo; solo agrega un override base.
//

import Foundation
import SwiftData

@Model
final class PatientSessionDefaultPrice {

    var id: UUID = UUID()

    /// Importe por defecto del paciente para el tipo de sesión indicado.
    var price: Decimal = 0

    /// Moneda ISO 4217 del precio por defecto.
    /// Se persiste junto al importe para evitar ambigüedad en escenarios multi-moneda.
    var currencyCode: String = ""

    // Trazabilidad administrativa
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var patient: Patient? = nil
    var sessionCatalogType: SessionCatalogType? = nil

    init(
        id: UUID = UUID(),
        price: Decimal = 0,
        currencyCode: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        patient: Patient? = nil,
        sessionCatalogType: SessionCatalogType? = nil
    ) {
        self.id = id
        self.price = price
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.patient = patient
        self.sessionCatalogType = sessionCatalogType
    }
}
