//
//  SessionCompletionTypes.swift
//  Ars Medica Digitalis
//
//  Tipos de error y problema de configuración del flujo de cierre financiero.
//  Separados de SessionViewModel para facilitar su uso en tests unitarios.
//

import Foundation

/// Explica por qué una sesión todavía no puede cerrarse financieramente.
/// Se expone al sheet para evitar UI engañosa cuando falta configuración base.
enum CompletionConfigurationIssue: Sendable, Equatable {
    case missingFinancialSessionType
    case missingPatientCurrency
    case missingResolvedPrice

    /// Devuelve un mensaje concreto para la UI según el contexto resuelto.
    /// Cuando falta precio pero la moneda sí existe, nombrar la divisa evita
    /// el ambiguo "Sin resolver" y orienta al profesional a corregir honorarios.
    func message(resolvedCurrencyCode: String = "") -> String {
        switch self {
        case .missingFinancialSessionType:
            return "Elegí un tipo facturable en la sesión antes de completarla."
        case .missingPatientCurrency:
            return "Configurá la moneda predeterminada en Paciente > Editar > Finanzas antes de completar la sesión."
        case .missingResolvedPrice:
            if resolvedCurrencyCode.isEmpty == false {
                return "Definí un honorario vigente en \(resolvedCurrencyCode) en Perfil > Honorarios para este tipo de sesión antes de completar."
            }

            return "Definí un honorario vigente en Perfil > Honorarios para este tipo de sesión antes de completar."
        }
    }
}

/// Errores controlados del flujo de cierre financiero.
/// Se usan para dar feedback claro cuando la UI intenta cerrar
/// una sesión con una intención de pago inválida.
enum SessionCompletionError: LocalizedError {
    case sessionAlreadyCompleted
    case invalidPartialAmount
    case missingFinancialSessionType
    case missingPatientCurrency
    case missingResolvedPrice(String)

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyCompleted:
            return "La sesión ya estaba completada."
        case .invalidPartialAmount:
            return "Ingresá un monto parcial mayor a cero y menor al total adeudado."
        case .missingFinancialSessionType:
            return "Elegí un tipo facturable antes de completar la sesión."
        case .missingPatientCurrency:
            return "Configurá la moneda predeterminada del paciente antes de completar la sesión."
        case .missingResolvedPrice(let resolvedCurrencyCode):
            if resolvedCurrencyCode.isEmpty == false {
                return "Definí un honorario vigente en \(resolvedCurrencyCode) para este tipo de sesión antes de completar."
            }

            return "Definí un honorario vigente para este tipo de sesión antes de completar."
        }
    }
}
