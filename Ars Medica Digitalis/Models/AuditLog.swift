//
//  AuditLog.swift
//  Ars Medica Digitalis
//
//  Registro inmutable de acciones clínicas críticas.
//  Append-only: nunca se modifica ni se borra una vez insertado.
//

import Foundation
import SwiftData

// MARK: - AuditAction

/// Tipo de acción clínica registrada en el audit trail.
enum AuditAction: String, Sendable {
    case create     = "create"
    case update     = "update"
    case softDelete = "softDelete"
    case restore    = "restore"
}

// MARK: - AuditEntityType

/// Tipo de entidad clínica sobre la que se ejecutó la acción.
enum AuditEntityType: String, Sendable {
    case patient         = "Patient"
    case diagnosis       = "Diagnosis"
    case priorTreatment  = "PriorTreatment"
    case hospitalization = "Hospitalization"
}

// MARK: - AuditLog

/// Entrada inmutable del audit trail clínico.
///
/// `actionRaw` y `entityTypeRaw` se persisten como String (raw value de sus enums)
/// para compatibilidad con SwiftData/CloudKit sin pérdida de legibilidad histórica.
/// Los computed vars `action` y `entityType` devuelven el valor tipado en runtime.
@Model
final class AuditLog {

    var id: UUID = UUID()
    var timestamp: Date = Date()

    /// Raw value de `AuditAction` — usar `action` para acceso tipado.
    var actionRaw: String = ""
    /// Raw value de `AuditEntityType` — usar `entityType` para acceso tipado.
    var entityTypeRaw: String = ""

    /// ID de la entidad afectada. Persiste aunque la entidad sea soft-deleted.
    var entityID: UUID = UUID()

    /// Actor que ejecutó la acción. "system" si no hay usuario identificable.
    var performedBy: String = "system"

    /// Contexto adicional opcional (ej. código CIE-11, campo modificado).
    var detail: String? = nil

    // MARK: - Typed accessors

    var action: AuditAction {
        AuditAction(rawValue: actionRaw) ?? .create
    }

    var entityType: AuditEntityType {
        AuditEntityType(rawValue: entityTypeRaw) ?? .patient
    }

    // MARK: - Init

    init(
        action: AuditAction,
        entityType: AuditEntityType,
        entityID: UUID,
        performedBy: String,
        detail: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.actionRaw = action.rawValue
        self.entityTypeRaw = entityType.rawValue
        self.entityID = entityID
        self.performedBy = performedBy
        self.detail = detail
    }
}
