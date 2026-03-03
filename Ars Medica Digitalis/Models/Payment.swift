//
//  Payment.swift
//  Ars Medica Digitalis
//
//  Pago aplicado a una sesión.
//  Se modela por separado para soportar pagos parciales o múltiples.
//

import Foundation
import SwiftData

@Model
final class Payment {

    var id: UUID = UUID()

    /// Importe cobrado en este movimiento.
    var amount: Decimal = 0

    /// Moneda efectiva del cobro.
    /// Se copia desde el snapshot de la sesión para conservar trazabilidad
    /// aunque luego cambie la moneda vigente del paciente.
    var currencyCode: String = ""

    /// Fecha efectiva del cobro.
    var paidAt: Date = Date()

    /// Nota administrativa opcional del pago.
    var notes: String = ""

    // Trazabilidad administrativa
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Flujo financiero de cobranza:
    // Session -> Payment.
    // La deuda se calculará luego como precio resuelto menos suma de pagos.
    var session: Session? = nil

    init(
        id: UUID = UUID(),
        amount: Decimal = 0,
        currencyCode: String = "",
        paidAt: Date = Date(),
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        session: Session? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currencyCode = currencyCode
        self.paidAt = paidAt
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.session = session
    }
}
