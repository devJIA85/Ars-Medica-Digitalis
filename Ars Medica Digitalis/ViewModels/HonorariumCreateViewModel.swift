//
//  HonorariumCreateViewModel.swift
//  Ars Medica Digitalis
//
//  Crea tipos facturables con su primera versión de precio.
//  Separamos esta escritura de la vista para no mezclar captura y persistencia.
//

import Foundation
import SwiftData

enum HonorariumCreateError: LocalizedError {
    case invalidName
    case invalidPrice
    case missingCurrency

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Ingresá un nombre para el honorario."
        case .invalidPrice:
            return "Ingresá un precio mayor a cero."
        case .missingCurrency:
            return "Elegí una moneda para el honorario."
        }
    }
}

@MainActor
@Observable
final class HonorariumCreateViewModel {

    var name: String = ""
    var currencyCode: String = "ARS"
    var price: Decimal = 0
    var effectiveFrom: Date = Date()

    var canSave: Bool {
        name.trimmed.isEmpty == false
        && currencyCode.isEmpty == false
        && price > 0
    }

    /// Crea el nodo del catálogo y su primera versión de precio en una sola
    /// transacción para que el tipo nunca exista sin un honorario vigente base.
    func save(for professional: Professional, in context: ModelContext) throws {
        let trimmedName = name.trimmed
        guard trimmedName.isEmpty == false else {
            throw HonorariumCreateError.invalidName
        }

        guard price > 0 else {
            throw HonorariumCreateError.invalidPrice
        }

        guard currencyCode.isEmpty == false else {
            throw HonorariumCreateError.missingCurrency
        }

        let nextSortOrder = ((professional.sessionCatalogTypes ?? []).map(\.sortOrder).max() ?? -1) + 1
        let sessionType = SessionCatalogType(
            name: trimmedName,
            sortOrder: nextSortOrder,
            professional: professional
        )
        context.insert(sessionType)

        let version = SessionTypePriceVersion(
            effectiveFrom: effectiveFrom,
            price: price,
            currencyCode: currencyCode,
            adjustmentSource: .manual,
            sessionCatalogType: sessionType
        )
        context.insert(version)

        try context.save()
    }
}
