//
//  FinancialLedgerEntry.swift
//  Ars Medica Digitalis
//
//  Representa un movimiento individual del libro mayor financiero de un paciente.
//  Se deriva de los datos existentes (Session completada = cargo, Payment = cobro)
//  sin almacenar estado redundante: la fuente de verdad sigue siendo Session y Payment.
//

import Foundation

/// Tipo de movimiento financiero en el libro mayor.
/// Cargo: ingreso devengado por una sesión completada.
/// Pago: cobro efectivo registrado sobre una o más sesiones.
enum FinancialMovementKind: String, Sendable {
    case charge    // cargo generado por sesión completada
    case payment   // cobro registrado
}

/// Fila inmutable del libro mayor financiero de un paciente.
/// `runningBalance` es el saldo acumulado DESPUÉS de aplicar este movimiento.
/// Immutable y Sendable: seguro para pasar entre contextos y vistas.
struct FinancialLedgerEntry: Identifiable, Sendable {

    let id: UUID
    let date: Date
    let kind: FinancialMovementKind

    /// Importe siempre positivo. La dirección está codificada en `kind`.
    let amount: Decimal
    let currencyCode: String

    /// Descripción legible del movimiento (tipo de sesión, nota del pago, etc.).
    let label: String

    /// Saldo acumulado del paciente en la moneda correspondiente luego de este movimiento.
    /// Cargos suman, pagos restan.
    let runningBalance: Decimal

    /// ID de la sesión origen. Disponible en ambos tipos para navegación futura.
    let sourceSessionID: UUID?
}
