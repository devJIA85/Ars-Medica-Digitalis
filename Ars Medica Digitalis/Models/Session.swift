//
//  Session.swift
//  Ars Medica Digitalis
//
//  Cada encuentro clínico entre el profesional y el paciente.
//  El campo notes es el corazón narrativo de la historia clínica.
//

import Foundation
import SwiftData
import UIKit

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
    /// Persistencia RTF estable: formato ISO-estándar.
    /// Primario para lectura; notesRichTextData se mantiene como fallback legado.
    @Attribute(.externalStorage)
    var notesRTFData: Data? = nil
    var chiefComplaint: String = ""          // Motivo de consulta
    var treatmentPlan: String = ""
    /// Resumen clínico breve (editable) generado por Apple Intelligence.
    var sessionSummary: String = ""
    /// Persistencia rica (iOS 26): plan terapéutico con formato.
    @Attribute(.externalStorage)
    var treatmentPlanRichTextData: Data = Data()
    /// Persistencia RTF estable (V2): plan terapéutico.
    @Attribute(.externalStorage)
    var treatmentPlanRTFData: Data? = nil
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

    var patient: Patient? = nil

    @Relationship(deleteRule: .cascade, inverse: \Diagnosis.session)
    var diagnoses: [Diagnosis] = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.session)
    var attachments: [Attachment] = []

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
    var payments: [Payment] = []

    /// API rica para la UI de edición.
    /// Conserva `notes` como fallback plano para compatibilidad y exportación.
    /// Estrategia triple fallback: RTF (V2 estable) → JSON (V1 legado) → texto plano.
    var notesRichText: AttributedString {
        get {
            if let data = notesRTFData, !data.isEmpty,
               let decoded = Self.decodeRTF(from: data) { return decoded }
            return Self.decodeRichText(from: notesRichTextData, fallbackPlainText: notes)
        }
        set {
            notes = String(newValue.characters)
            notesRTFData = Self.encodeRTF(newValue)
            notesRichTextData = Self.encodeRichText(newValue)  // mantiene legado para rollback
        }
    }

    /// API rica para el plan terapéutico.
    /// Mantiene `treatmentPlan` como lectura plana en vistas que aún no renderizan atributos.
    /// Estrategia triple fallback: RTF (V2 estable) → JSON (V1 legado) → texto plano.
    var treatmentPlanRichText: AttributedString {
        get {
            if let data = treatmentPlanRTFData, !data.isEmpty,
               let decoded = Self.decodeRTF(from: data) { return decoded }
            return Self.decodeRichText(from: treatmentPlanRichTextData, fallbackPlainText: treatmentPlan)
        }
        set {
            treatmentPlan = String(newValue.characters)
            treatmentPlanRTFData = Self.encodeRTF(newValue)
            treatmentPlanRichTextData = Self.encodeRichText(newValue)  // mantiene legado para rollback
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
    ///
    /// Estrategia de resolución:
    /// - Cortesía → 0 (sin importar snapshots).
    /// - Completada con `finalPriceSnapshot` → snapshot (valor histórico inmutable).
    /// - Si `resolvedPrice` existe (> 0), se usa como valor persistido compatible.
    /// - Si falta precio persistido, recalcula en vivo con `SessionPricingService`
    ///   para no dejar en cero sesiones históricas sin snapshot ni caché.
    @MainActor
    var effectivePrice: Decimal {
        if isCourtesy { return 0 }
        if isCompleted, let snapshot = finalPriceSnapshot { return snapshot }
        if resolvedPrice > 0 { return resolvedPrice }
        return pricingService.resolveDynamicPrice(for: self)
    }

    /// Moneda efectiva de la sesión.
    ///
    /// Estrategia de resolución:
    /// - Completada con `finalCurrencySnapshot` no vacío → snapshot (moneda histórica inmutable).
    /// - Si falta snapshot, recalcula la moneda vigente para `scheduledAt` usando
    ///   el historial del paciente y cae al `currencyCode` escalar por compatibilidad.
    @MainActor
    var effectiveCurrency: String {
        if isCompleted, let snapshot = finalCurrencySnapshot, !snapshot.isEmpty { return snapshot }
        guard let patient else { return "" }
        let resolvedCurrency = pricingService.resolveCurrency(for: patient, at: scheduledAt)
        return resolvedCurrency.isEmpty ? patient.currencyCode : resolvedCurrency
    }

    /// Suma de pagos efectivamente registrados sobre la sesión.
    /// Se calcula en vivo para soportar pagos parciales o múltiples.
    var totalPaid: Decimal {
        payments.reduce(0) { partialResult, payment in
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

    @MainActor
    private var pricingService: SessionPricingService {
        SessionPricingService(
            modelContext: modelContext ?? patient?.modelContext ?? financialSessionType?.modelContext
        )
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
        diagnoses: [Diagnosis] = [],
        attachments: [Attachment] = [],
        financialSessionType: SessionCatalogType? = nil,
        resolvedPrice: Decimal = 0,
        priceWasManuallyOverridden: Bool = false,
        finalPriceSnapshot: Decimal? = nil,
        finalCurrencySnapshot: String? = nil,
        isCourtesy: Bool = false,
        payments: [Payment] = [],
        notesRTFData: Data? = nil,
        treatmentPlanRTFData: Data? = nil
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
        self.notesRTFData = notesRTFData
        self.treatmentPlanRTFData = treatmentPlanRTFData
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Encapsula la estrategia Codable -> Data para no repetirla fuera del modelo.
    private static func encodeRichText(_ text: AttributedString) -> Data {
        (try? encoder.encode(text)) ?? Data()
    }

    /// Decodifica rich text y cae a plano cuando se abre una sesión legada.
    private static func decodeRichText(from data: Data, fallbackPlainText: String) -> AttributedString {
        guard data.isEmpty == false,
              let decoded = try? decoder.decode(AttributedString.self, from: data) else {
            return AttributedString(fallbackPlainText)
        }

        return decoded
    }

    // MARK: - RTF helpers (V2)

    /// Serializa un AttributedString a RTF usando NSAttributedString.
    /// Retorna nil si la conversión falla (e.g., string vacío sin atributos).
    static func encodeRTF(_ text: AttributedString) -> Data? {
        let nsString = NSAttributedString(text)
        guard nsString.length > 0 else { return nil }
        return try? nsString.data(
            from: NSRange(location: 0, length: nsString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    /// Deserializa RTF a AttributedString con scope UIKit.
    /// Retorna nil si los datos son inválidos o no corresponden a RTF.
    static func decodeRTF(from data: Data) -> AttributedString? {
        guard let nsString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else { return nil }
        return try? AttributedString(nsString, including: \.uiKit)
    }
}
