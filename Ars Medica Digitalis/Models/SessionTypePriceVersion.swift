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
    /// Se persiste como String para máxima compatibilidad con SwiftData/CloudKit.
    /// `adjustmentSource` expone acceso tipado para el dominio.
    @Attribute(originalName: "adjustmentSource")
    private var adjustmentSourceRaw: String = PriceAdjustmentSource.manual.rawValue

    // Trazabilidad administrativa
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var sessionCatalogType: SessionCatalogType? = nil

    var adjustmentSource: PriceAdjustmentSource {
        get { PriceAdjustmentSource(rawValue: adjustmentSourceRaw) ?? .manual }
        set { adjustmentSourceRaw = newValue.rawValue }
    }

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
        self.adjustmentSourceRaw = adjustmentSource.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sessionCatalogType = sessionCatalogType
    }
}
