//
//  PricingAdjustmentPolicy.swift
//  Ars Medica Digitalis
//
//  Política global de ajuste de honorarios del profesional.
//  Centraliza la regla base para sugerencias automáticas sin tocar la UI.
//

import Foundation
import SwiftData

@Model
final class PricingAdjustmentPolicy {

    /// Cada cuántos meses se reevalúa si conviene sugerir un ajuste.
    /// Se persiste globalmente para que todos los tipos facturables compartan
    /// la misma política comercial por defecto.
    var frequencyInMonths: Int = 3

    /// Umbral opcional de IPC acumulado que también puede disparar sugerencia.
    /// Permite reaccionar antes del plazo fijo cuando la inflación acumulada
    /// supera un valor considerado crítico por el profesional.
    var ipcThreshold: Decimal? = nil

    /// Habilita o deshabilita todo el motor de sugerencias automáticas.
    /// Se guarda explícitamente para que el dominio pueda apagar la lógica
    /// sin borrar configuración histórica ni referencias futuras.
    var isEnabled: Bool = true

    /// Fecha base global opcional para calcular inflación acumulada.
    /// Si no existe, cada tipo usa la fecha de su última versión de precio.
    var globalReferenceDate: Date? = nil

    /// Última vez que el usuario descartó una sugerencia.
    /// En este PR solo se persiste para dejar el dominio listo; el uso
    /// comportamental llegará cuando exista la UI de revisión.
    var lastSuggestionDismissedAt: Date? = nil

    /// Relación inversa opcional por compatibilidad con CloudKit.
    /// El profesional es dueño de una única política global de ajustes.
    var professional: Professional? = nil

    init(
        frequencyInMonths: Int = 3,
        ipcThreshold: Decimal? = nil,
        isEnabled: Bool = true,
        globalReferenceDate: Date? = nil,
        lastSuggestionDismissedAt: Date? = nil,
        professional: Professional? = nil
    ) {
        self.frequencyInMonths = frequencyInMonths
        self.ipcThreshold = ipcThreshold
        self.isEnabled = isEnabled
        self.globalReferenceDate = globalReferenceDate
        self.lastSuggestionDismissedAt = lastSuggestionDismissedAt
        self.professional = professional
    }
}
