//
//  SessionDrafts.swift
//  Ars Medica Digitalis
//
//  Tipos de borrador y snapshot usados en el flujo de alta/edición de sesiones.
//  Separados de SessionViewModel para permitir su uso en tests y en vistas
//  sin arrastrar la lógica del ViewModel completo.
//

import Foundation

/// Intención de pago elegida por la UI antes de persistir movimientos.
/// Se separa de la ejecución real para validar la decisión del usuario
/// antes de escribir Payment y evitar lógica financiera en la vista.
enum PaymentIntent: Sendable {
    case full
    case partial(Decimal)
    case none
}

/// Borrador in-memory para la sheet de finalización.
/// Expone el importe pendiente y la moneda ya resueltos sin crear todavía
/// ningún Payment, de modo que la UI pueda decidir cómo cerrar la sesión.
struct CompletionDraft: Identifiable, Sendable {
    let sessionID: UUID
    let amountDue: Decimal
    let currencyCode: String
    let isCourtesy: Bool
    let configurationIssue: CompletionConfigurationIssue?

    var id: UUID { sessionID }

    var isFinanciallyConfigured: Bool {
        configurationIssue == nil
    }
}

/// Snapshot liviano para mostrar el resumen financiero dentro del formulario.
/// Se calcula on-demand para que la UI vea precio y moneda estimados antes
/// de completar la sesión, sin persistir nada ni duplicar lógica en la vista.
struct SessionPricingPreview: Sendable {
    let amount: Decimal
    let currencyCode: String
    let isCourtesy: Bool
    let configurationIssue: CompletionConfigurationIssue?

    var isResolved: Bool {
        configurationIssue == nil
    }
}

/// Borrador financiero puro para cálculos previos a la persistencia.
/// Mantiene referencias a modelos SwiftData solo dentro del MainActor y evita
/// crear Session @Model temporales que luego puedan filtrarse al contexto.
struct SessionFinancialDraft {
    let scheduledAt: Date
    let patient: Patient?
    let financialSessionType: SessionCatalogType?
    let isCourtesy: Bool
    let isCompleted: Bool
}

/// Snapshot inmutable del formulario antes de guardar.
/// Se usa para que validación, sheet de cobro y persistencia trabajen con el
/// mismo estado, sin depender de cambios reactivos posteriores de la vista.
struct SessionFormSnapshot: Sendable {
    let sessionDate: Date
    let sessionType: String
    let durationMinutes: Int
    let chiefComplaint: String
    let notes: String
    let treatmentPlan: String
    let sessionSummary: String
    let notesRichText: AttributedString
    let treatmentPlanRichText: AttributedString
    let status: String
    let financialSessionTypeID: UUID?
    let isCourtesy: Bool
    let selectedDiagnoses: [ICD11SearchResult]

    /// Mantiene el init histórico (notes/treatmentPlan en plano) y agrega
    /// rich text opcional para no romper tests ni consumidores existentes.
    init(
        sessionDate: Date,
        sessionType: String,
        durationMinutes: Int,
        chiefComplaint: String,
        notes: String,
        treatmentPlan: String,
        sessionSummary: String = "",
        notesRichText: AttributedString? = nil,
        treatmentPlanRichText: AttributedString? = nil,
        status: String,
        financialSessionTypeID: UUID?,
        isCourtesy: Bool,
        selectedDiagnoses: [ICD11SearchResult]
    ) {
        self.sessionDate = sessionDate
        self.sessionType = sessionType
        self.durationMinutes = durationMinutes
        self.chiefComplaint = chiefComplaint
        self.notes = notes
        self.treatmentPlan = treatmentPlan
        self.sessionSummary = sessionSummary
        self.notesRichText = notesRichText ?? AttributedString(notes)
        self.treatmentPlanRichText = treatmentPlanRichText ?? AttributedString(treatmentPlan)
        self.status = status
        self.financialSessionTypeID = financialSessionTypeID
        self.isCourtesy = isCourtesy
        self.selectedDiagnoses = selectedDiagnoses
    }

    /// Cuando el guardado requiere sheet de cobro, persistimos primero como
    /// programada y cerramos recién tras confirmar la intención de pago.
    /// Así evitamos sesiones intermedias ya insertadas antes de tiempo.
    func snapshotForCompletionPersistence() -> SessionFormSnapshot {
        SessionFormSnapshot(
            sessionDate: sessionDate,
            sessionType: sessionType,
            durationMinutes: durationMinutes,
            chiefComplaint: chiefComplaint,
            notes: notes,
            treatmentPlan: treatmentPlan,
            sessionSummary: sessionSummary,
            notesRichText: notesRichText,
            treatmentPlanRichText: treatmentPlanRichText,
            status: SessionStatusMapping.programada.rawValue,
            financialSessionTypeID: financialSessionTypeID,
            isCourtesy: isCourtesy,
            selectedDiagnoses: selectedDiagnoses
        )
    }
}
