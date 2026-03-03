//
//  SessionTypePriceUpdateViewModel.swift
//  Ars Medica Digitalis
//
//  Orquesta la creación de nuevas versiones de honorarios sugeridas por IPC.
//  Mantiene la persistencia fuera de la vista y preserva el historial intacto.
//

import Foundation
import SwiftData

enum SessionTypePriceUpdateError: LocalizedError {
    case invalidPrice
    case missingCurrency
    case sessionTypeDoesNotBelongToProfessional

    var errorDescription: String? {
        switch self {
        case .invalidPrice,
             .missingCurrency,
             .sessionTypeDoesNotBelongToProfessional:
            return L10n.tr("honorarios.update_error.message")
        }
    }
}

@MainActor
@Observable
final class SessionTypePriceUpdateViewModel {

    private let context: ModelContext
    private let professional: Professional
    private let sessionType: SessionCatalogType

    /// Proveedor de fecha inyectable.
    /// Se mantiene fuera de applyUpdate para que tests y previews puedan fijar
    /// la fecha efectiva de la nueva versión sin depender del reloj del sistema.
    private let nowProvider: () -> Date

    let currentPrice: Decimal
    let currentCurrencyCode: String
    let ipcAccumulated: Decimal
    let suggestedPrice: Decimal

    /// Precio editable por el usuario antes de confirmar.
    /// Nace con la sugerencia automática, pero puede ajustarse manualmente
    /// sin alterar la decisión del motor económico ni versiones previas.
    var editablePrice: Decimal

    var sessionTypeName: String {
        sessionType.name
    }

    /// Centraliza la validación mínima para que la vista solo refleje estado.
    /// El precio debe ser positivo y la moneda debe existir para preservar
    /// la semántica multi-moneda del historial versionado.
    var canApply: Bool {
        editablePrice > 0 && currentCurrencyCode.isEmpty == false
    }

    init(
        snapshot: SessionTypeBusinessSnapshot,
        professional: Professional,
        context: ModelContext,
        nowProvider: @escaping () -> Date = { Date() }
    ) {
        self.context = context
        self.professional = professional
        self.sessionType = snapshot.sessionType
        self.nowProvider = nowProvider
        self.currentPrice = snapshot.currentPrice ?? snapshot.suggestedPrice ?? 0
        self.currentCurrencyCode = snapshot.currentCurrencyCode
            ?? snapshot.lastPriceVersion?.currencyCode
            ?? ""
        self.ipcAccumulated = snapshot.ipcAccumulated
        self.suggestedPrice = snapshot.suggestedPrice ?? self.currentPrice
        self.editablePrice = self.suggestedPrice
    }

    /// Aplica la actualización creando una nueva versión.
    /// Nunca reescribe versiones previas porque el historial de honorarios debe
    /// seguir explicando qué valor estuvo vigente en cada momento.
    func applyUpdate() throws {
        guard sessionType.professional?.id == professional.id else {
            throw SessionTypePriceUpdateError.sessionTypeDoesNotBelongToProfessional
        }

        guard editablePrice > 0 else {
            throw SessionTypePriceUpdateError.invalidPrice
        }

        guard currentCurrencyCode.isEmpty == false else {
            throw SessionTypePriceUpdateError.missingCurrency
        }

        let effectiveFrom = nowProvider()
        let newVersion = SessionTypePriceVersion(
            effectiveFrom: effectiveFrom,
            price: editablePrice,
            currencyCode: currentCurrencyCode,
            adjustmentSource: .ipcSuggested,
            createdAt: effectiveFrom,
            updatedAt: effectiveFrom,
            sessionCatalogType: sessionType
        )

        context.insert(newVersion)
        try context.save()
    }
}
