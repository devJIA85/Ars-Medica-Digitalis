//
//  AdjustmentSuggestionEngine.swift
//  Ars Medica Digitalis
//
//  Motor puro que decide si conviene sugerir un ajuste de honorarios.
//  No depende de SwiftData ni de red para que sea completamente testeable.
//

import Foundation

struct AdjustmentSuggestion: Equatable, Sendable {
    let shouldSuggest: Bool
    let suggestedPrice: Decimal?
    let ipcAccumulated: Decimal
    let monthsSinceUpdate: Int
}

struct AdjustmentSuggestionEngine: Sendable {

    nonisolated init() {}

    /// Evalúa si corresponde sugerir un ajuste según la política global.
    /// Separamos esta lógica en un motor puro para que la regla comercial sea
    /// fácil de probar, reutilizar y evolucionar sin acoplarla a SwiftData.
    nonisolated func evaluate(
        currentPrice: Decimal,
        monthsSinceUpdate: Int,
        ipcAccumulated: Decimal,
        policy: PricingAdjustmentPolicy
    ) -> AdjustmentSuggestion {
        let normalizedMonths = max(0, monthsSinceUpdate)
        let normalizedIPC = max(Decimal.zero, ipcAccumulated)

        guard policy.isEnabled else {
            return AdjustmentSuggestion(
                shouldSuggest: false,
                suggestedPrice: nil,
                ipcAccumulated: normalizedIPC,
                monthsSinceUpdate: normalizedMonths
            )
        }

        let reachedFrequency = normalizedMonths >= max(0, policy.frequencyInMonths)
        let reachedThreshold = policy.ipcThreshold.map { normalizedIPC >= $0 } ?? false
        let shouldSuggest = reachedFrequency || reachedThreshold

        let suggestedPrice = shouldSuggest
            ? roundedCurrencyValue(currentPrice * (Decimal(1) + normalizedIPC))
            : nil

        return AdjustmentSuggestion(
            shouldSuggest: shouldSuggest,
            suggestedPrice: suggestedPrice,
            ipcAccumulated: normalizedIPC,
            monthsSinceUpdate: normalizedMonths
        )
    }

    /// Redondea a dos decimales para que la sugerencia quede lista para UI
    /// y para persistencia futura sin acumular residuos binarios visuales.
    private nonisolated func roundedCurrencyValue(_ value: Decimal) -> Decimal {
        var mutableValue = value
        var roundedValue = Decimal()
        NSDecimalRound(&roundedValue, &mutableValue, 2, .plain)
        return roundedValue
    }
}
