//
//  SessionTypeBusinessService.swift
//  Ars Medica Digitalis
//
//  Construye snapshots económicos de cada tipo de sesión.
//  Centraliza la inteligencia comercial para futuras pantallas de honorarios.
//

import Foundation
import SwiftData

struct SessionTypeBusinessSnapshot {
    let sessionType: SessionCatalogType
    let currentPrice: Decimal?
    let currentCurrencyCode: String?
    /// Fecha desde la que rige el honorario actualmente vigente.
    /// Se expone aparte porque la UI necesita mostrar "Vigente desde"
    /// sin reconstruir la lógica de versionado ni depender del modelo crudo.
    let effectiveFrom: Date?
    let lastPriceVersion: SessionTypePriceVersion?
    let monthsSinceLastUpdate: Int
    let ipcAccumulated: Decimal
    let shouldSuggestUpdate: Bool
    let suggestedPrice: Decimal?
}

@MainActor
final class SessionTypeBusinessService {

    private let ipcIndicatorService: IPCIndicatorService
    private let suggestionEngine: AdjustmentSuggestionEngine
    private let calendar: Calendar

    init(
        ipcIndicatorService: IPCIndicatorService? = nil,
        suggestionEngine: AdjustmentSuggestionEngine? = nil,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.ipcIndicatorService = ipcIndicatorService ?? IPCIndicatorService(calendar: calendar)
        self.suggestionEngine = suggestionEngine ?? AdjustmentSuggestionEngine()
    }

    /// Compatibilidad transitoria para callers antiguos que todavía dependen
    /// de la resolución implícita del profesional. El contrato preferido es
    /// recibir el Professional desde la capa superior para evitar supuestos.
    @available(*, deprecated, message: "Use businessSnapshots(for:context:at:) instead.")
    func loadSnapshots(
        context: ModelContext,
        at referenceDate: Date = Date()
    ) async throws -> [SessionTypeBusinessSnapshot] {
        guard let professional = try fetchActiveProfessional(in: context) else {
            return []
        }

        return try await businessSnapshots(
            for: professional,
            context: context,
            at: referenceDate
        )
    }

    /// Devuelve el snapshot económico de un tipo facturable puntual.
    /// Se usa un servicio dedicado para desacoplar la futura UI premium
    /// de las reglas de IPC, política global y versionado histórico.
    func businessSnapshot(
        for sessionType: SessionCatalogType,
        context: ModelContext,
        at referenceDate: Date = Date()
    ) async throws -> SessionTypeBusinessSnapshot {
        let versions = try fetchPriceVersions(
            sessionTypeID: sessionType.id,
            in: context
        )

        let currentVersion = resolveCurrentVersion(
            from: versions,
            at: referenceDate
        )
        let latestVersion = resolveLatestVersion(from: versions)
        let policy = resolvePolicy(for: sessionType.professional)
        let baseDate = policy.globalReferenceDate
            ?? latestVersion?.effectiveFrom
            ?? referenceDate
        let monthsSinceLastUpdate = max(
            0,
            calendar.dateComponents([.month], from: baseDate, to: referenceDate).month ?? 0
        )
        let ipcAccumulated = try await ipcIndicatorService.accumulatedIPC(
            from: baseDate,
            to: referenceDate
        )

        let suggestion: AdjustmentSuggestion
        if let currentVersion {
            suggestion = suggestionEngine.evaluate(
                currentPrice: currentVersion.price,
                monthsSinceUpdate: monthsSinceLastUpdate,
                ipcAccumulated: ipcAccumulated,
                policy: policy
            )
        } else {
            suggestion = AdjustmentSuggestion(
                shouldSuggest: false,
                suggestedPrice: nil,
                ipcAccumulated: ipcAccumulated,
                monthsSinceUpdate: monthsSinceLastUpdate
            )
        }

        /// Blindamos el snapshot para que nunca exponga un precio sugerido
        /// cuando la regla comercial decidió no sugerir ajuste. Así la capa
        /// de presentación no tiene que defenderse de estados inconsistentes.
        let safeSuggestedPrice = suggestion.shouldSuggest ? suggestion.suggestedPrice : nil

        return SessionTypeBusinessSnapshot(
            sessionType: sessionType,
            currentPrice: currentVersion?.price,
            currentCurrencyCode: currentVersion?.currencyCode,
            effectiveFrom: currentVersion?.effectiveFrom,
            lastPriceVersion: latestVersion,
            monthsSinceLastUpdate: suggestion.monthsSinceUpdate,
            ipcAccumulated: suggestion.ipcAccumulated,
            shouldSuggestUpdate: suggestion.shouldSuggest,
            suggestedPrice: safeSuggestedPrice
        )
    }

    /// Construye snapshots para todo el catálogo del profesional.
    /// Mantiene el orden estable del tablero para que una vista posterior
    /// no necesite duplicar sorting ni queries de dominio.
    func businessSnapshots(
        for professional: Professional,
        context: ModelContext,
        at referenceDate: Date = Date()
    ) async throws -> [SessionTypeBusinessSnapshot] {
        let sessionTypes = try fetchSessionTypes(
            professionalID: professional.id,
            in: context
        )

        var snapshots: [SessionTypeBusinessSnapshot] = []
        for sessionType in sessionTypes {
            let snapshot = try await businessSnapshot(
                for: sessionType,
                context: context,
                at: referenceDate
            )
            snapshots.append(snapshot)
        }

        return snapshots
    }

    /// Busca el profesional dueño del contexto activo.
    /// Hoy asumimos una sola cuenta profesional por container, por eso
    /// tomamos el primer registro ordenado por creación de forma estable.
    private func fetchActiveProfessional(
        in context: ModelContext
    ) throws -> Professional? {
        let descriptor = FetchDescriptor<Professional>(
            predicate: #Predicate<Professional> { _ in
                true
            },
            sortBy: [
                SortDescriptor(\Professional.createdAt),
                SortDescriptor(\Professional.updatedAt),
            ]
        )

        return try context.fetch(descriptor).first
    }

    private func fetchSessionTypes(
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

    private func fetchPriceVersions(
        sessionTypeID: UUID,
        in context: ModelContext
    ) throws -> [SessionTypePriceVersion] {
        let descriptor = FetchDescriptor<SessionTypePriceVersion>(
            predicate: #Predicate<SessionTypePriceVersion> { version in
                version.sessionCatalogType?.id == sessionTypeID
            },
            sortBy: [
                SortDescriptor(\SessionTypePriceVersion.effectiveFrom, order: .reverse),
                SortDescriptor(\SessionTypePriceVersion.updatedAt, order: .reverse),
            ]
        )

        return try context.fetch(descriptor)
    }

    /// Toma la versión vigente al día consultado.
    /// Ignora precios futuros porque una sugerencia económica debe partir
    /// del honorario que realmente está en vigor hoy.
    private func resolveCurrentVersion(
        from versions: [SessionTypePriceVersion],
        at referenceDate: Date
    ) -> SessionTypePriceVersion? {
        versions.first { $0.effectiveFrom <= referenceDate }
    }

    /// Conserva la última versión registrada aunque todavía sea futura.
    /// Esto permite medir antigüedad comercial de la política del tipo.
    private func resolveLatestVersion(
        from versions: [SessionTypePriceVersion]
    ) -> SessionTypePriceVersion? {
        versions.first
    }

    /// Cuando no existe política persistida devolvemos una política inactiva.
    /// Esto evita sugerencias sorpresa y deja el servicio seguro para datos
    /// históricos previos a la creación del módulo de inteligencia económica.
    private func resolvePolicy(for professional: Professional?) -> PricingAdjustmentPolicy {
        if let policy = professional?.pricingAdjustmentPolicy {
            return policy
        }

        return PricingAdjustmentPolicy(isEnabled: false)
    }
}

typealias BusinessSnapshot = SessionTypeBusinessSnapshot
