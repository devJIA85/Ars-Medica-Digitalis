//
//  PatientDebtCurrencySummary.swift
//  Ars Medica Digitalis
//
//  Resume la deuda acumulada de un paciente en una moneda puntual.
//  Se separa en un struct liviano para reutilizarlo entre vistas y
//  view models sin acoplar la UI al array completo de sesiones.
//

import Foundation

struct PatientDebtCurrencySummary: Identifiable, Sendable {
    let currencyCode: String
    let debt: Decimal
    let sessionCount: Int

    var id: String { currencyCode }
}
