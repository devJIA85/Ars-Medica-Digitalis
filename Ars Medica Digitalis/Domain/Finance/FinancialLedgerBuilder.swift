//
//  FinancialLedgerBuilder.swift
//  Ars Medica Digitalis
//
//  Construye el libro mayor financiero de un paciente a partir de datos existentes:
//  sesiones completadas (= cargos) y pagos registrados (= cobros).
//  No almacena estado propio: es una función determinística sobre el grafo de objetos.
//

import Foundation

enum FinancialLedgerBuilder {

    // MARK: - Libro mayor

    /// Construye el libro mayor de un paciente filtrado por moneda.
    ///
    /// Cargos: sesiones completadas, no cortesía, con precio > 0 en la moneda dada.
    /// Cobros: pagos (`Payment`) asociados a esas sesiones.
    /// El saldo acumulado se calcula desde cero, en orden cronológico.
    /// En empate de fecha, los cargos preceden a los cobros.
    ///
    /// - Parameters:
    ///   - patient: El paciente cuyo historial se quiere derivar.
    ///   - currencyCode: Moneda a filtrar. Si está vacío, retorna `[]`.
    /// - Returns: Lista ordenada de más antiguo a más reciente, con saldo acumulado.
    static func entries(for patient: Patient, currencyCode: String) -> [FinancialLedgerEntry] {
        guard !currencyCode.isEmpty else { return [] }

        var raw: [(date: Date, sortOrder: Int, entry: FinancialLedgerEntry)] = []

        for session in patient.sessions ?? [] {
            guard session.status == SessionStatusMapping.completada.rawValue else { continue }
            guard !session.isCourtesy else { continue }

            let sessionCurrency = session.finalCurrencySnapshot ?? session.effectiveCurrency
            guard sessionCurrency == currencyCode else { continue }

            let chargeAmount = resolvedChargeAmount(for: session)
            guard chargeAmount > 0 else { continue }

            let chargeDate = session.completedAt ?? session.sessionDate

            // Cargo por la sesión completada
            let chargeEntry = FinancialLedgerEntry(
                id: session.id,
                date: chargeDate,
                kind: .charge,
                amount: chargeAmount,
                currencyCode: currencyCode,
                label: sessionTypeLabel(for: session),
                runningBalance: 0,
                sourceSessionID: session.id
            )
            raw.append((date: chargeDate, sortOrder: 0, entry: chargeEntry))

            // Cobros asociados a esta sesión
            for payment in session.payments ?? [] where payment.currencyCode == currencyCode {
                let paymentEntry = FinancialLedgerEntry(
                    id: payment.id,
                    date: payment.paidAt,
                    kind: .payment,
                    amount: payment.amount,
                    currencyCode: currencyCode,
                    label: payment.notes.isEmpty ? "Pago" : payment.notes,
                    runningBalance: 0,
                    sourceSessionID: session.id
                )
                raw.append((date: payment.paidAt, sortOrder: 1, entry: paymentEntry))
            }
        }

        // Ordenar cronológicamente; en empate, cargo antes que cobro
        raw.sort { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.date < rhs.date
        }

        // Calcular saldo acumulado en un solo pase
        var balance: Decimal = 0
        return raw.map { item in
            switch item.entry.kind {
            case .charge:  balance += item.entry.amount
            case .payment: balance -= item.entry.amount
            }
            return FinancialLedgerEntry(
                id: item.entry.id,
                date: item.entry.date,
                kind: item.entry.kind,
                amount: item.entry.amount,
                currencyCode: item.entry.currencyCode,
                label: item.entry.label,
                runningBalance: balance,
                sourceSessionID: item.entry.sourceSessionID
            )
        }
    }

    // MARK: - Monedas disponibles

    /// Retorna los códigos de moneda con al menos un cargo facturable.
    /// Permite que la UI construya selectores de moneda sin generar el libro completo.
    static func availableCurrencies(for patient: Patient) -> [String] {
        var currencies: Set<String> = []

        for session in patient.sessions ?? [] {
            guard session.status == SessionStatusMapping.completada.rawValue else { continue }
            guard !session.isCourtesy else { continue }

            let currency = session.finalCurrencySnapshot ?? session.effectiveCurrency
            guard !currency.isEmpty else { continue }
            guard resolvedChargeAmount(for: session) > 0 else { continue }

            currencies.insert(currency)
        }

        return currencies.sorted()
    }

    // MARK: - Privados

    /// Precio efectivo de una sesión completada.
    /// `finalPriceSnapshot` es el valor canónico fijado al cierre;
    /// `resolvedPrice` es el respaldo legado para sesiones históricas.
    private static func resolvedChargeAmount(for session: Session) -> Decimal {
        if let snapshot = session.finalPriceSnapshot, snapshot > 0 {
            return snapshot
        }
        return session.resolvedPrice > 0 ? session.resolvedPrice : 0
    }

    private static func sessionTypeLabel(for session: Session) -> String {
        switch SessionTypeMapping(rawValue: session.sessionType) {
        case .presencial:    return "Sesión presencial"
        case .videollamada:  return "Sesión por videollamada"
        case .telefonica:   return "Sesión telefónica"
        case .none:          return "Sesión"
        }
    }
}

