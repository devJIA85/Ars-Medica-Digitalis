//
//  SessionTypePriceVersion.swift
//  Ars Medica Digitalis
//
//  Versiona el precio de un tipo de sesión a partir de una fecha de vigencia.
//  La lógica de resolución se implementará más adelante.
//

import Foundation
import SwiftData

enum PriceAdjustmentSource: String, Codable, Sendable {
    case manual
    case ipcSuggested
    case bulkUpdate
}

@Model
final class SessionTypePriceVersion {

    var id: UUID = UUID()

    /// Fecha desde la cual este precio pasa a ser candidato vigente.
    /// Se usa scheduledAt/sessionDate como criterio en fases posteriores.
    var effectiveFrom: Date = Date()

    /// Importe nominal sin conversión de moneda.
    var price: Decimal = 0

    /// Moneda ISO 4217 del precio versionado.
    /// Es necesaria para soportar catálogo multi-moneda real.
    var currencyCode: String = ""

    /// Origen del ajuste que generó esta versión.
    /// Se persiste para distinguir cambios manuales, sugeridos por IPC o
    /// actualizaciones masivas futuras sin alterar la lógica vigente actual.
    var adjustmentSource: PriceAdjustmentSource = PriceAdjustmentSource.manual

    // Trazabilidad administrativa
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var sessionCatalogType: SessionCatalogType? = nil

    init(
        id: UUID = UUID(),
        effectiveFrom: Date = Date(),
        price: Decimal = 0,
        currencyCode: String = "",
        adjustmentSource: PriceAdjustmentSource = PriceAdjustmentSource.manual,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sessionCatalogType: SessionCatalogType? = nil
    ) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.price = price
        self.currencyCode = currencyCode
        self.adjustmentSource = adjustmentSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sessionCatalogType = sessionCatalogType
    }
}
