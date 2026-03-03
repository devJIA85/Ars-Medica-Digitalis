//
//  SessionTypeCatalogViewModel.swift
//  Ars Medica Digitalis
//
//  Convierte el catálogo de honorarios en un tablero estratégico.
//  Expone precio vigente, historial e impacto futuro sin escribir en SwiftData.
//

import Foundation
import SwiftData

/// Importe nominal agrupado por moneda.
/// Se usa como bloque reutilizable porque el módulo financiero no convierte
/// divisas: cada total debe mostrarse en su currencyCode original.
struct HonorariumAmount: Identifiable, Equatable {
    let currencyCode: String
    let amount: Decimal

    var id: String { currencyCode }
}

/// Precio actualmente vigente para una moneda puntual del catálogo.
/// Se separa del historial para que la UI pueda destacar el precio activo
/// sin volver a recorrer toda la línea temporal.
struct SessionTypeCurrentPrice: Identifiable, Equatable {
    let versionID: UUID
    let currencyCode: String
    let price: Decimal
    let effectiveFrom: Date

    var id: String { currencyCode }
}

/// Entrada de timeline para versionado de honorarios.
/// Guarda vigencia de inicio y fin lógico para explicar al profesional
/// cómo cambió el valor sin reescribir historia previa.
struct SessionTypePriceHistoryEntry: Identifiable, Equatable {
    let id: UUID
    let currencyCode: String
    let price: Decimal
    let effectiveFrom: Date
    let effectiveUntil: Date?
    let isCurrent: Bool
}

/// Resumen estratégico de un tipo facturable.
/// Mantiene referencias directas a SwiftData para habilitar drill-down y edición
/// futura sin duplicar identidad de dominio en DTOs intermedios.
struct SessionTypeCatalogSummary: Identifiable {
    let sessionType: SessionCatalogType
    let currentPrices: [SessionTypeCurrentPrice]
    let priceHistory: [SessionTypePriceHistoryEntry]
    let affectedFutureSessionsCount: Int
    let projectedMonthlyImpact: [HonorariumAmount]

    var id: UUID { sessionType.id }

    /// Conveniencia para una UI simple de una sola moneda.
    /// La fuente definitiva sigue siendo currentPrices porque el catálogo
    /// soporta múltiples monedas vigentes al mismo tiempo.
    var currentPrice: Decimal {
        currentPrices.first?.price ?? 0
    }
}

@MainActor
@Observable
final class SessionTypeCatalogViewModel {

    /// Fecha de referencia para decidir qué versión está vigente "hoy".
    /// Se inyecta para hacer tests deterministas y para soportar previews
    /// de impacto en fechas futuras sin tocar persistencia.
    var referenceDate: Date

    /// Resumen completo listo para renderizar como tablero de honorarios.
    var catalogSummaries: [SessionTypeCatalogSummary] = []

    /// Promedio de honorarios vigentes por moneda.
    /// Se deja preparado para métricas ejecutivas futuras sin recalcular en la UI.
    var averageCurrentPrices: [HonorariumAmount] = []

    private let calendar: Calendar

    init(
        referenceDate: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    /// Relee el catálogo del profesional y recompone todas las métricas derivadas.
    /// Es idempotente porque solo consulta SwiftData y actualiza estado en memoria.
    func refresh(for professional: Professional, in context: ModelContext) throws {
        let catalogTypes = try fetchCatalogTypes(
            professionalID: professional.id,
            in: context
        )

        let monthRange = FinanceDashboardViewModel.monthRange(
            for: referenceDate,
            calendar: calendar
        )

        catalogSummaries = try catalogTypes.map { sessionType in
            let versions = try fetchPriceVersions(
                sessionTypeID: sessionType.id,
                in: context
            )
            let affectedSessions = try fetchAffectedFutureSessions(
                sessionTypeID: sessionType.id,
                from: referenceDate,
                in: context
            )

            let monthlySessions = affectedSessions.filter { session in
                session.scheduledAt >= monthRange.start
                && session.scheduledAt < monthRange.end
            }

            return SessionTypeCatalogSummary(
                sessionType: sessionType,
                currentPrices: buildCurrentPrices(
                    from: versions,
                    at: referenceDate
                ),
                priceHistory: buildPriceHistory(
                    from: versions,
                    at: referenceDate
                ),
                affectedFutureSessionsCount: affectedSessions.count,
                projectedMonthlyImpact: sumByCurrency(monthlySessions) { session in
                    HonorariumAmount(
                        currencyCode: session.effectiveCurrency,
                        amount: session.effectivePrice
                    )
                }
            )
        }
        .sorted(by: sortCatalogSummary)

        averageCurrentPrices = buildAverageCurrentPrices(from: catalogSummaries)
    }

    /// Trae solo el catálogo del profesional actual.
    /// El predicate usa el UUID de dominio para evitar depender de identidad
    /// de memoria y mantener consistencia entre contextos.
    private func fetchCatalogTypes(
        professionalID: UUID,
        in context: ModelContext
    ) throws -> [SessionCatalogType] {
        let descriptor = FetchDescriptor<SessionCatalogType>(
            predicate: #Predicate<SessionCatalogType> { sessionType in
                sessionType.professional?.id == professionalID
            },
            sortBy: [
                SortDescriptor(\SessionCatalogType.sortOrder),
                SortDescriptor(\SessionCatalogType.name),
            ]
        )

        return try context.fetch(descriptor)
    }

    /// Lee el historial completo de precios de un tipo para construir la timeline.
    /// Se ordena ascendente para calcular el fin lógico de cada versión sin ambigüedad.
    private func fetchPriceVersions(
        sessionTypeID: UUID,
        in context: ModelContext
    ) throws -> [SessionTypePriceVersion] {
        let descriptor = FetchDescriptor<SessionTypePriceVersion>(
            predicate: #Predicate<SessionTypePriceVersion> { version in
                version.sessionCatalogType?.id == sessionTypeID
            },
            sortBy: [
                SortDescriptor(\SessionTypePriceVersion.currencyCode),
                SortDescriptor(\SessionTypePriceVersion.effectiveFrom),
                SortDescriptor(\SessionTypePriceVersion.updatedAt),
            ]
        )

        return try context.fetch(descriptor)
    }

    /// Busca solo sesiones futuras realmente afectables por un cambio de honorario.
    /// Excluye completadas, canceladas, cortesías y overrides manuales porque
    /// esas sesiones ya no deberían moverse con el precio dinámico del catálogo.
    private func fetchAffectedFutureSessions(
        sessionTypeID: UUID,
        from date: Date,
        in context: ModelContext
    ) throws -> [Session] {
        let canceledStatus = SessionStatusMapping.cancelada.rawValue
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.financialSessionType?.id == sessionTypeID
                && session.sessionDate >= date
                && session.completedAt == nil
                && session.priceWasManuallyOverridden == false
                && session.isCourtesy == false
                && session.status != canceledStatus
            },
            sortBy: [SortDescriptor(\Session.sessionDate)]
        )

        return try context.fetch(descriptor)
    }

    /// Resuelve el precio vigente por moneda al día de referencia.
    /// Si una moneda solo tiene versiones futuras, no se la marca como vigente
    /// para que la UI no confunda un valor programado con uno activo hoy.
    private func buildCurrentPrices(
        from versions: [SessionTypePriceVersion],
        at date: Date
    ) -> [SessionTypeCurrentPrice] {
        let referenceDay = date.startOfDayDate(calendar: calendar)
        let currentByCurrency = Dictionary(grouping: versions, by: \.currencyCode)
            .compactMap { currencyCode, currencyVersions -> SessionTypeCurrentPrice? in
                let currentVersion = currencyVersions
                    .filter {
                        $0.effectiveFrom.startOfDayDate(calendar: calendar) <= referenceDay
                    }
                    .sorted(by: sortVersionsDescending)
                    .first

                guard let currentVersion else { return nil }
                return SessionTypeCurrentPrice(
                    versionID: currentVersion.id,
                    currencyCode: currencyCode,
                    price: currentVersion.price,
                    effectiveFrom: currentVersion.effectiveFrom
                )
            }

        return currentByCurrency.sorted { lhs, rhs in
            lhs.currencyCode < rhs.currencyCode
        }
    }

    /// Construye la timeline completa del tipo, incluyendo versiones futuras.
    /// El fin lógico se calcula con la siguiente versión de la misma moneda para
    /// explicar claramente cuándo deja de aplicar un honorario.
    private func buildPriceHistory(
        from versions: [SessionTypePriceVersion],
        at date: Date
    ) -> [SessionTypePriceHistoryEntry] {
        let currentIDsByCurrency = Dictionary(
            uniqueKeysWithValues: buildCurrentPrices(from: versions, at: date).map { current in
                (current.currencyCode, current.versionID)
            }
        )

        return Dictionary(grouping: versions, by: \.currencyCode)
            .values
            .flatMap { currencyVersions in
                let sortedVersions = currencyVersions.sorted(by: sortVersionsAscending)
                return sortedVersions.enumerated().map { index, version in
                    let nextVersion = sortedVersions[safe: index + 1]
                    return SessionTypePriceHistoryEntry(
                        id: version.id,
                        currencyCode: version.currencyCode,
                        price: version.price,
                        effectiveFrom: version.effectiveFrom,
                        effectiveUntil: nextVersion?.effectiveFrom,
                        isCurrent: currentIDsByCurrency[version.currencyCode] == version.id
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.effectiveFrom == rhs.effectiveFrom {
                    return lhs.currencyCode < rhs.currencyCode
                }
                return lhs.effectiveFrom > rhs.effectiveFrom
            }
    }

    /// Calcula el promedio de precios vigentes por moneda.
    /// Agruparlo acá evita que la vista mezcle reglas de negocio con presentación.
    private func buildAverageCurrentPrices(
        from summaries: [SessionTypeCatalogSummary]
    ) -> [HonorariumAmount] {
        let grouped = summaries
            .flatMap(\.currentPrices)
            .reduce(into: [String: (total: Decimal, count: Decimal)]()) { partialResult, price in
                let current = partialResult[price.currencyCode] ?? (0, 0)
                partialResult[price.currencyCode] = (
                    total: current.total + price.price,
                    count: current.count + 1
                )
            }

        return grouped.map { currencyCode, aggregate in
            let average = aggregate.count > 0
                ? aggregate.total / aggregate.count
                : 0
            return HonorariumAmount(currencyCode: currencyCode, amount: average)
        }
        .sorted { lhs, rhs in
            lhs.currencyCode < rhs.currencyCode
        }
    }

    /// Suma elementos por currencyCode para mantener el tablero multi-moneda.
    /// Se usa tanto para ingresos proyectados como para futuras métricas premium.
    private func sumByCurrency<Element>(
        _ elements: [Element],
        transform: (Element) -> HonorariumAmount
    ) -> [HonorariumAmount] {
        let grouped = elements.reduce(into: [String: Decimal]()) { partialResult, element in
            let amount = transform(element)
            guard amount.currencyCode.isEmpty == false else { return }
            partialResult[amount.currencyCode, default: 0] += amount.amount
        }

        return grouped.map { currencyCode, amount in
            HonorariumAmount(currencyCode: currencyCode, amount: amount)
        }
        .sorted { lhs, rhs in
            lhs.currencyCode < rhs.currencyCode
        }
    }

    private func sortCatalogSummary(
        _ lhs: SessionTypeCatalogSummary,
        _ rhs: SessionTypeCatalogSummary
    ) -> Bool {
        if lhs.sessionType.isActive != rhs.sessionType.isActive {
            return lhs.sessionType.isActive && !rhs.sessionType.isActive
        }

        if lhs.sessionType.sortOrder != rhs.sessionType.sortOrder {
            return lhs.sessionType.sortOrder < rhs.sessionType.sortOrder
        }

        return lhs.sessionType.name.localizedCaseInsensitiveCompare(rhs.sessionType.name) == .orderedAscending
    }

    private func sortVersionsAscending(
        _ lhs: SessionTypePriceVersion,
        _ rhs: SessionTypePriceVersion
    ) -> Bool {
        if lhs.effectiveFrom == rhs.effectiveFrom {
            return lhs.updatedAt < rhs.updatedAt
        }
        return lhs.effectiveFrom < rhs.effectiveFrom
    }

    private func sortVersionsDescending(
        _ lhs: SessionTypePriceVersion,
        _ rhs: SessionTypePriceVersion
    ) -> Bool {
        if lhs.effectiveFrom == rhs.effectiveFrom {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.effectiveFrom > rhs.effectiveFrom
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
