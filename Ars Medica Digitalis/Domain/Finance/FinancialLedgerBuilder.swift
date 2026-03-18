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

        for item in billableSessions(for: patient) where item.currency == currencyCode {
            let chargeDate = item.session.completedAt ?? item.session.sessionDate

            raw.append((
                date: chargeDate,
                sortOrder: 0,
                entry: FinancialLedgerEntry(
                    id: item.session.id,
                    date: chargeDate,
                    kind: .charge,
                    amount: item.amount,
                    currencyCode: currencyCode,
                    label: sessionTypeLabel(for: item.session),
                    runningBalance: 0,
                    sourceSessionID: item.session.id
                )
            ))

            for payment in item.session.payments where payment.currencyCode == currencyCode {
                raw.append((
                    date: payment.paidAt,
                    sortOrder: 1,
                    entry: FinancialLedgerEntry(
                        id: payment.id,
                        date: payment.paidAt,
                        kind: .payment,
                        amount: payment.amount,
                        currencyCode: currencyCode,
                        label: payment.notes.isEmpty ? "Pago" : payment.notes,
                        runningBalance: 0,
                        sourceSessionID: item.session.id
                    )
                ))
            }
        }

        raw.sort { lhs, rhs in
            lhs.date == rhs.date ? lhs.sortOrder < rhs.sortOrder : lhs.date < rhs.date
        }

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
    /// Delega en `billableSessions` para que las reglas de elegibilidad
    /// vivan en un único lugar.
    static func availableCurrencies(for patient: Patient) -> [String] {
        Set(billableSessions(for: patient).map(\.currency)).sorted()
    }

    // MARK: - Privados

    /// **Única fuente de verdad para la elegibilidad financiera.**
    ///
    /// Define exactamente qué sesiones generan cargo en el libro mayor.
    /// Tanto `entries(for:currencyCode:)` como `availableCurrencies(for:)` delegan aquí;
    /// cualquier cambio en las reglas de inclusión se aplica una sola vez.
    ///
    /// Criterios de elegibilidad (todos deben cumplirse):
    /// 1. `status == "completada"` — sesiones abiertas o canceladas no generan cargo.
    /// 2. `isCourtesy == false` — las sesiones de cortesía no generan ingreso.
    /// 3. Moneda resuelta no vacía — `finalCurrencySnapshot` con prioridad, luego `effectiveCurrency`.
    /// 4. Importe > 0 — `finalPriceSnapshot` con prioridad, luego `resolvedPrice`.
    private static func billableSessions(
        for patient: Patient
    ) -> [(session: Session, currency: String, amount: Decimal)] {
        patient.sessions.compactMap { session in
            guard session.status == SessionStatusMapping.completada.rawValue,
                  !session.isCourtesy else { return nil }
            let currency = session.finalCurrencySnapshot ?? session.effectiveCurrency
            guard !currency.isEmpty else { return nil }
            let amount = resolvedChargeAmount(for: session)
            guard amount > 0 else { return nil }
            return (session: session, currency: currency, amount: amount)
        }
    }

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
