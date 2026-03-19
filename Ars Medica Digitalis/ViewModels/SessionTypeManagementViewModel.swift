//
//  SessionTypeManagementViewModel.swift
//  Ars Medica Digitalis
//
//  Gestiona renombre y baja logica de tipos facturables sin perder historial.
//

import Foundation
import SwiftData

enum SessionTypeManagementError: LocalizedError, Equatable {
    case invalidName
    case invalidPrice
    case missingCurrency
    case duplicateName
    case sessionTypeDoesNotBelongToProfessional

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Ingresá un nombre para el tipo de sesión."
        case .invalidPrice:
            return "Ingresá un valor mayor a cero para el honorario."
        case .missingCurrency:
            return "Elegí una moneda para el honorario."
        case .duplicateName:
            return "Ya existe otro tipo de sesión con ese nombre."
        case .sessionTypeDoesNotBelongToProfessional:
            return "No se pudo administrar este tipo de sesión."
        }
    }
}

@MainActor
@Observable
final class SessionTypeManagementViewModel {

    private let context: ModelContext
    private let professional: Professional
    private let sessionType: SessionCatalogType

    var name: String
    var currencyCode: String
    var price: Decimal
    var effectiveFrom: Date
    var colorToken: String
    var symbolName: String

    private let initialPrice: Decimal
    private let initialCurrencyCode: String
    private let initialEffectiveFrom: Date

    init(
        snapshot: SessionTypeBusinessSnapshot,
        professional: Professional,
        context: ModelContext
    ) {
        self.sessionType = snapshot.sessionType
        self.professional = professional
        self.context = context
        self.name = snapshot.sessionType.name

        let fallbackCurrency = snapshot.currentCurrencyCode
            ?? snapshot.lastPriceVersion?.currencyCode
            ?? professional.defaultPatientCurrencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let fallbackPrice = snapshot.currentPrice
            ?? snapshot.lastPriceVersion?.price
            ?? 0
        let suggestedEffectiveFrom: Date
        if snapshot.currentPrice != nil {
            suggestedEffectiveFrom = Date().startOfDayDate()
        } else {
            suggestedEffectiveFrom = (snapshot.lastPriceVersion?.effectiveFrom ?? Date()).startOfDayDate()
        }

        let resolvedCurrencyCode = fallbackCurrency.isEmpty ? "ARS" : fallbackCurrency
        let resolvedPrice = fallbackPrice
        let resolvedEffectiveFrom = suggestedEffectiveFrom

        self.currencyCode = resolvedCurrencyCode
        self.price = resolvedPrice
        self.effectiveFrom = resolvedEffectiveFrom
        self.colorToken = snapshot.sessionType.colorToken
        self.symbolName = snapshot.sessionType.iconSystemName

        self.initialPrice = resolvedPrice
        self.initialCurrencyCode = resolvedCurrencyCode
        self.initialEffectiveFrom = resolvedEffectiveFrom.startOfDayDate()
    }

    var canSave: Bool {
        name.trimmed.isEmpty == false
        && currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        && price > 0
    }

    var isSuggestedDefault: Bool {
        professional.defaultFinancialSessionTypeID == sessionType.id
    }

    func save() throws {
        try validateOwnership()

        let trimmedName = name.trimmed
        guard trimmedName.isEmpty == false else {
            throw SessionTypeManagementError.invalidName
        }

        guard price > 0 else {
            throw SessionTypeManagementError.invalidPrice
        }

        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard normalizedCurrencyCode.isEmpty == false else {
            throw SessionTypeManagementError.missingCurrency
        }

        guard isDuplicateName(trimmedName) == false else {
            throw SessionTypeManagementError.duplicateName
        }

        let now = Date()
        sessionType.name = trimmedName
        sessionType.iconSystemName = resolvedSymbolName
        sessionType.colorToken = resolvedColorToken.rawValue
        sessionType.updatedAt = now
        professional.updatedAt = now

        if shouldCreateManualPriceVersion(
            normalizedCurrencyCode: normalizedCurrencyCode,
            effectiveFrom: effectiveFrom.startOfDayDate()
        ) {
            let newVersion = SessionTypePriceVersion(
                effectiveFrom: effectiveFrom.startOfDayDate(),
                price: price,
                currencyCode: normalizedCurrencyCode,
                adjustmentSource: .manual,
                sessionCatalogType: sessionType
            )
            context.insert(newVersion)
        }

        try context.save()
    }

    func archive() throws {
        try validateOwnership()

        let now = Date()
        sessionType.isActive = false
        sessionType.updatedAt = now

        if professional.defaultFinancialSessionTypeID == sessionType.id {
            professional.defaultFinancialSessionTypeID = nil
        }
        professional.updatedAt = now

        try context.save()
    }

    private func validateOwnership() throws {
        guard sessionType.professional?.id == professional.id else {
            throw SessionTypeManagementError.sessionTypeDoesNotBelongToProfessional
        }
    }

    private func isDuplicateName(_ candidateName: String) -> Bool {
        let normalizedCandidate = normalizedSessionTypeName(candidateName)
        let professionalID = professional.id
        let descriptor = FetchDescriptor<SessionCatalogType>(
            predicate: #Predicate<SessionCatalogType> { sessionType in
                sessionType.professional?.id == professionalID
            }
        )

        let sessionTypes = (try? context.fetch(descriptor)) ?? professional.sessionCatalogTypes

        return sessionTypes.contains { existingType in
            guard existingType.id != sessionType.id else { return false }
            return normalizedSessionTypeName(existingType.name) == normalizedCandidate
        }
    }

    private func normalizedSessionTypeName(_ value: String) -> String {
        value
            .trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private func shouldCreateManualPriceVersion(
        normalizedCurrencyCode: String,
        effectiveFrom: Date
    ) -> Bool {
        price != initialPrice
        || normalizedCurrencyCode != initialCurrencyCode
        || effectiveFrom != initialEffectiveFrom
    }

    private var resolvedColorToken: SessionTypeColorToken {
        SessionTypeColorToken(rawValue: colorToken) ?? .blue
    }

    private var resolvedSymbolName: String {
        SessionTypeSymbolCatalog.isSupported(symbolName)
        ? symbolName
        : SessionTypeSymbolCatalog.defaultSymbolName
    }
}
