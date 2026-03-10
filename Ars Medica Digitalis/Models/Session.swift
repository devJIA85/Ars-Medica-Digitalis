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
    /// Persistencia rica (iOS 26): AttributedString codificado en Data.
    /// Se guarda aparte para preservar formato (negrita, listas, encabezados).
    @Attribute(.externalStorage)
    var notesRichTextData: Data = Data()
    var chiefComplaint: String = ""          // Motivo de consulta
    var treatmentPlan: String = ""
    /// Resumen clínico breve (editable) generado por Apple Intelligence.
    var sessionSummary: String = ""
    /// Persistencia rica (iOS 26): plan terapéutico con formato.
    @Attribute(.externalStorage)
    var treatmentPlanRichTextData: Data = Data()
    var status: String = SessionStatusMapping.completada.rawValue      // "programada" | "completada" | "cancelada"
    /// Identificador del evento en el calendario del sistema (EventKit).
    /// Permite actualizar/eliminar la misma cita sin duplicar eventos.
    var calendarEventIdentifier: String? = nil

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

    /// API rica para la UI de edición.
    /// Conserva `notes` como fallback plano para compatibilidad y exportación.
    var notesRichText: AttributedString {
        get {
            Self.decodeRichText(
                from: notesRichTextData,
                fallbackPlainText: notes
            )
        }
        set {
            notes = String(newValue.characters)
            notesRichTextData = Self.encodeRichText(newValue)
        }
    }

    /// API rica para el plan terapéutico.
    /// Mantiene `treatmentPlan` como lectura plana en vistas que aún no renderizan atributos.
    var treatmentPlanRichText: AttributedString {
        get {
            Self.decodeRichText(
                from: treatmentPlanRichTextData,
                fallbackPlainText: treatmentPlan
            )
        }
        set {
            treatmentPlan = String(newValue.characters)
            treatmentPlanRichTextData = Self.encodeRichText(newValue)
        }
    }

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

    /// Alias semántico para sincronización con EventKit.
    var startDate: Date {
        get { sessionDate }
        set { sessionDate = newValue }
    }

    /// Fin de sesión calculado por duración para agenda y calendario.
    var endDate: Date {
        let minutes = max(durationMinutes, 1)
        return startDate.addingTimeInterval(TimeInterval(minutes * 60))
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

        let service = SessionPricingService(modelContext: modelContext)
        if isCompleted {
            // Mientras la sesión completada aún no congeló snapshots, por ejemplo
            // durante la validación previa al guardado, seguimos resolviendo en vivo
            // para no degradar a cero una sesión que sí tiene honorario válido.
            return finalPriceSnapshot ?? service.resolveDynamicPrice(for: self)
        }

        return service.resolveDynamicPrice(for: self)
    }

    /// Moneda efectiva de la sesión.
    /// Las sesiones completadas leen el snapshot para congelar la historia;
    /// las no completadas siguen la moneda vigente del paciente por fecha.
    @MainActor
    var effectiveCurrency: String {
        guard let patient else { return "" }
        let service = SessionPricingService(modelContext: modelContext)
        if isCompleted {
            // Mismo criterio que el precio: una completada temporal sin snapshot
            // todavía debe poder validarse y mostrarse con su moneda dinámica.
            return finalCurrencySnapshot ?? service.resolveCurrency(for: patient, at: scheduledAt)
        }

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
        notesRichText: AttributedString? = nil,
        chiefComplaint: String = "",
        treatmentPlan: String = "",
        sessionSummary: String = "",
        treatmentPlanRichText: AttributedString? = nil,
        status: String = SessionStatusMapping.completada.rawValue,
        calendarEventIdentifier: String? = nil,
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
        let resolvedNotesRichText = notesRichText ?? AttributedString(notes)
        self.notes = String(resolvedNotesRichText.characters)
        self.notesRichTextData = Self.encodeRichText(resolvedNotesRichText)
        self.chiefComplaint = chiefComplaint
        let resolvedTreatmentPlanRichText = treatmentPlanRichText ?? AttributedString(treatmentPlan)
        self.treatmentPlan = String(resolvedTreatmentPlanRichText.characters)
        self.sessionSummary = sessionSummary
        self.treatmentPlanRichTextData = Self.encodeRichText(resolvedTreatmentPlanRichText)
        self.status = status
        self.calendarEventIdentifier = calendarEventIdentifier
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

    /// Encapsula la estrategia Codable -> Data para no repetirla fuera del modelo.
    private static func encodeRichText(_ text: AttributedString) -> Data {
        (try? JSONEncoder().encode(text)) ?? Data()
    }

    /// Decodifica rich text y cae a plano cuando se abre una sesión legada.
    private static func decodeRichText(from data: Data, fallbackPlainText: String) -> AttributedString {
        guard data.isEmpty == false,
              let decoded = try? JSONDecoder().decode(AttributedString.self, from: data) else {
            return AttributedString(fallbackPlainText)
        }

        return decoded
    }
}
