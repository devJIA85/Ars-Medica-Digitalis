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

    /// Reutiliza la moneda administrativa base del profesional como punto
    /// de partida para nuevos honorarios y así mantener coherencia visual
    /// entre pacientes recién creados y el catálogo facturable.
    func applyDefaults(from professional: Professional) {
        let professionalCurrency = professional.defaultPatientCurrencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard professionalCurrency.isEmpty == false else {
            return
        }

        currencyCode = professionalCurrency
    }

    /// Crea el nodo del catálogo y su primera versión de precio en una sola
    /// transacción para que el tipo nunca exista sin un honorario vigente base.
    func save(for professional: Professional, in context: ModelContext) throws {
        let trimmedName = name.trimmed
        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard trimmedName.isEmpty == false else {
            throw HonorariumCreateError.invalidName
        }

        guard price > 0 else {
            throw HonorariumCreateError.invalidPrice
        }

        guard normalizedCurrencyCode.isEmpty == false else {
            throw HonorariumCreateError.missingCurrency
        }

        let sessionType = reusableSessionType(
            named: trimmedName,
            for: professional,
            in: context
        ) ?? {
            let nextSortOrder = ((professional.sessionCatalogTypes ?? []).map(\.sortOrder).max() ?? -1) + 1
            let newSessionType = SessionCatalogType(
                name: trimmedName,
                sortOrder: nextSortOrder,
                professional: professional
            )
            context.insert(newSessionType)
            return newSessionType
        }()

        // Si el usuario vuelve a cargar el mismo honorario en otra moneda,
        // lo anexamos al mismo tipo facturable para no multiplicar tipos
        // visualmente iguales que después no se distinguen en la agenda.
        sessionType.isActive = true
        sessionType.updatedAt = Date()

        // El primer honorario queda sugerido como default operativo para
        // sesiones nuevas y evita que la agenda arranque sin tipo facturable.
        if professional.defaultFinancialSessionTypeID == nil {
            professional.defaultFinancialSessionTypeID = sessionType.id
            professional.updatedAt = Date()
        }

        let version = SessionTypePriceVersion(
            effectiveFrom: effectiveFrom.startOfDayDate(),
            price: price,
            currencyCode: normalizedCurrencyCode,
            adjustmentSource: .manual,
            sessionCatalogType: sessionType
        )
        context.insert(version)

        try context.save()
    }

    /// Reutiliza tipos con el mismo nombre lógico para que distintas monedas
    /// vivan como versiones del mismo honorario y no como tipos paralelos.
    private func reusableSessionType(
        named name: String,
        for professional: Professional,
        in context: ModelContext
    ) -> SessionCatalogType? {
        let normalizedName = normalizedSessionTypeName(name)
        let professionalID = professional.id
        let descriptor = FetchDescriptor<SessionCatalogType>(
            predicate: #Predicate<SessionCatalogType> { sessionType in
                sessionType.professional?.id == professionalID
            },
            sortBy: [
                SortDescriptor(\SessionCatalogType.sortOrder),
                SortDescriptor(\SessionCatalogType.createdAt),
            ]
        )

        // Consultamos SwiftData antes que la relación viva porque en app real
        // el Professional puede llegar sin hijos materializados todavía.
        let sessionTypes = (try? context.fetch(descriptor))
            ?? (professional.sessionCatalogTypes ?? [])

        return sessionTypes
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .first { sessionType in
                normalizedSessionTypeName(sessionType.name) == normalizedName
            }
    }

    private func normalizedSessionTypeName(_ value: String) -> String {
        value
            .trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
