//
//  Session.swift
//  Ars Medica Digitalis
//
//  Cada encuentro clínico entre el profesional y el paciente.
//  El campo notes es el corazón narrativo de la historia clínica.
//

import Foundation
import SwiftData

enum PaymentState: String, Sendable {
    case unpaid
    case paidPartial
    case paidFull
}

@Model
final class Session {

    var id: UUID = UUID()

    var sessionDate: Date = Date()
    var sessionType: String = SessionTypeMapping.presencial.rawValue   // "presencial" | "videollamada" | "telefónica"
    var durationMinutes: Int = 50
    var notes: String = ""                   // ⚠️ CRÍTICO — contenido clínico privado
    var chiefComplaint: String = ""          // Motivo de consulta
    var treatmentPlan: String = ""
    var status: String = SessionStatusMapping.completada.rawValue      // "programada" | "completada" | "cancelada"

    // Trazabilidad
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Fecha efectiva de cierre clínico-financiero.
    /// Se persiste para poder calcular devengado y deuda por mes de completado
    /// sin depender de scheduledAt ni de la última edición de la sesión.
    var completedAt: Date? = nil

    // Relaciones opcionales por requisito CloudKit
    var patient: Patient? = nil

    @Relationship(deleteRule: .cascade, inverse: \Diagnosis.session)
    var diagnoses: [Diagnosis]? = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.session)
    var attachments: [Attachment]? = []

    // Flujo financiero desacoplado del registro clínico:
    // Session referencia un tipo facturable y acumula Payment sin tocar
    // la modalidad clínica existente ni activar lógica de cálculo en este PR.
    var financialSessionType: SessionCatalogType? = nil
    /// Campo legado auxiliar.
    /// Se conserva para compatibilidad, pero la resolución activa vive en SessionPricingService.
    var resolvedPrice: Decimal = 0
    var priceWasManuallyOverridden: Bool = false
    /// Snapshot definitivo al completarse la sesión.
    /// Preserva el importe histórico incluso si cambian moneda o precios futuros.
    var finalPriceSnapshot: Decimal? = nil
    /// Snapshot de moneda al completarse.
    /// Evita reinterpretar el ingreso histórico cuando la moneda del paciente cambia.
    var finalCurrencySnapshot: String? = nil
    /// Marca sesiones que no generan ingreso.
    /// Permite registrar encuentros asistenciales sin deuda ni cobro.
    var isCourtesy: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Payment.session)
    var payments: [Payment]? = []

    /// Acceso tipado para modalidad sin romper compatibilidad de persistencia.
    var sessionTypeValue: SessionTypeMapping {
        get { SessionTypeMapping(sessionTypeRawValue: sessionType) ?? .presencial }
        set { sessionType = newValue.rawValue }
    }

    /// Acceso tipado para estado sin romper compatibilidad de persistencia.
    var sessionStatusValue: SessionStatusMapping {
        get { SessionStatusMapping(sessionStatusRawValue: status) ?? .completada }
        set { status = newValue.rawValue }
    }

    /// Alias semántico para la capa financiera.
    /// Mantiene sessionDate como storage para no romper el dominio clínico existente.
    var scheduledAt: Date {
        get { sessionDate }
        set { sessionDate = newValue }
    }

    /// Indica si la sesión ya quedó cerrada clínicamente.
    /// Se usa para decidir entre precio dinámico y snapshot histórico.
    var isCompleted: Bool {
        sessionStatusValue == .completada
    }

    /// Precio efectivo de la sesión.
    /// Si está completada usa snapshot histórico; si no, resuelve dinámicamente.
    /// En sesiones de cortesía siempre vale cero para evitar ingresos/deuda artificial.
    @MainActor
    var effectivePrice: Decimal {
        if isCourtesy {
            return 0
        }

        if isCompleted {
            return finalPriceSnapshot ?? 0
        }

        let service = SessionPricingService(modelContext: modelContext)
        return service.resolveDynamicPrice(for: self)
    }

    /// Moneda efectiva de la sesión.
    /// Las sesiones completadas leen el snapshot para congelar la historia;
    /// las no completadas siguen la moneda vigente del paciente por fecha.
    @MainActor
    var effectiveCurrency: String {
        if isCompleted {
            return finalCurrencySnapshot ?? ""
        }

        guard let patient else { return "" }
        let service = SessionPricingService(modelContext: modelContext)
        return service.resolveCurrency(for: patient, at: scheduledAt)
    }

    /// Suma de pagos efectivamente registrados sobre la sesión.
    /// Se calcula en vivo para soportar pagos parciales o múltiples.
    var totalPaid: Decimal {
        (payments ?? []).reduce(0) { partialResult, payment in
            partialResult + payment.amount
        }
    }

    /// Deuda pendiente de la sesión.
    /// En cortesía se fuerza a cero porque la sesión no genera ingreso.
    @MainActor
    var debt: Decimal {
        if isCourtesy {
            return 0
        }

        let remaining = effectivePrice - totalPaid
        return remaining > 0 ? remaining : 0
    }

    /// Estado agregado de cobranza.
    /// Resume rápidamente si la sesión está impaga, paga parcial o totalmente.
    @MainActor
    var paymentState: PaymentState {
        if isCourtesy {
            return .paidFull
        }

        let price = effectivePrice
        if price <= 0 {
            return .paidFull
        }

        if totalPaid >= price {
            return .paidFull
        }

        if totalPaid > 0 {
            return .paidPartial
        }

        return .unpaid
    }

    init(
        id: UUID = UUID(),
        sessionDate: Date = Date(),
        sessionType: String = SessionTypeMapping.presencial.rawValue,
        durationMinutes: Int = 50,
        notes: String = "",
        chiefComplaint: String = "",
        treatmentPlan: String = "",
        status: String = SessionStatusMapping.completada.rawValue,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        patient: Patient? = nil,
        diagnoses: [Diagnosis]? = [],
        attachments: [Attachment]? = [],
        financialSessionType: SessionCatalogType? = nil,
        resolvedPrice: Decimal = 0,
        priceWasManuallyOverridden: Bool = false,
        finalPriceSnapshot: Decimal? = nil,
        finalCurrencySnapshot: String? = nil,
        isCourtesy: Bool = false,
        payments: [Payment]? = []
    ) {
        self.id = id
        self.sessionDate = sessionDate
        self.sessionType = sessionType
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.chiefComplaint = chiefComplaint
        self.treatmentPlan = treatmentPlan
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.patient = patient
        self.diagnoses = diagnoses
        self.attachments = attachments
        self.financialSessionType = financialSessionType
        self.resolvedPrice = resolvedPrice
        self.priceWasManuallyOverridden = priceWasManuallyOverridden
        self.finalPriceSnapshot = finalPriceSnapshot
        self.finalCurrencySnapshot = finalCurrencySnapshot
        self.isCourtesy = isCourtesy
        self.payments = payments
    }
}
