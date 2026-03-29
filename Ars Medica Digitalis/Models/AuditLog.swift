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
    /// Visualización de datos clínicos del paciente.
    case read       = "read"
    /// Exportación de datos fuera del dispositivo (ej. PDF).
    case export     = "export"
}

// MARK: - AuditEntityType

/// Tipo de entidad clínica sobre la que se ejecutó la acción.
enum AuditEntityType: String, Sendable {
    case patient         = "Patient"
    case diagnosis       = "Diagnosis"
    case priorTreatment  = "PriorTreatment"
    case hospitalization = "Hospitalization"
}

// MARK: - AuditSeverity

/// Nivel de criticidad del evento de auditoría.
///
/// Derivado automáticamente del tipo de acción via `AuditAction.defaultSeverity`.
/// Permite filtrar eventos por impacto sin analizar la acción completa.
enum AuditSeverity: String, Sendable {
    /// Acciones de bajo riesgo: lecturas, creaciones.
    case info       = "info"
    /// Mutaciones clínicas: updates, borrados lógicos, restauraciones.
    case sensitive  = "sensitive"
    /// Datos que abandonan el dispositivo: exportaciones.
    case critical   = "critical"
}

extension AuditAction {
    /// Severity por defecto asociado a cada tipo de acción.
    /// Se usa en `AuditService.log()` cuando el caller no sobreescribe el valor.
    var defaultSeverity: AuditSeverity {
        switch self {
        case .read:       .info
        case .create:     .info
        case .update:     .sensitive
        case .softDelete: .sensitive
        case .restore:    .sensitive
        case .export:     .critical
        }
    }
}

// MARK: - AuditLog

/// Entrada inmutable del audit trail clínico.
///
/// ## Política append-only
/// Una vez insertado, ningún registro puede modificarse ni eliminarse.
/// - No llamar a `context.delete(_:)` sobre instancias de `AuditLog`.
/// - No modificar ninguna propiedad después de la inserción inicial.
/// - Las migraciones de esquema solo agregan columnas opcionales o con default;
///   nunca alteran datos existentes.
/// Esta restricción es un requisito de compliance clínico y debe mantenerse
/// en cualquier refactor futuro.
///
/// ## Almacenamiento
/// Los campos `*Raw` se persisten como String (raw value) para compatibilidad
/// con SwiftData/CloudKit sin pérdida de legibilidad histórica.
/// Los computed vars tipados (`action`, `entityType`, `severity`) se usan en runtime.
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

    /// ID de sesión clínica relacionada, si aplica.
    var sessionID: UUID? = nil

    /// Raw value de `AuditSeverity`.
    /// Inicializado con `.info` para garantizar que no haya valores inválidos
    /// en registros nuevos ni en migraciones desde V3 (donde este campo no existía).
    var severityRaw: String = AuditSeverity.info.rawValue

    // MARK: - Typed accessors

    var action: AuditAction {
        AuditAction(rawValue: actionRaw) ?? .create
    }

    var entityType: AuditEntityType {
        AuditEntityType(rawValue: entityTypeRaw) ?? .patient
    }

    /// Severity del evento. Fallback a `.info` para registros migrados de V3
    /// cuyo `severityRaw` fue sobrescrito con el default del campo.
    var severity: AuditSeverity {
        AuditSeverity(rawValue: severityRaw) ?? .info
    }

    // MARK: - Init

    init(
        action: AuditAction,
        entityType: AuditEntityType,
        entityID: UUID,
        performedBy: String,
        detail: String? = nil,
        sessionID: UUID? = nil,
        severity: AuditSeverity? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.actionRaw = action.rawValue
        self.entityTypeRaw = entityType.rawValue
        self.entityID = entityID
        self.performedBy = performedBy
        self.detail = detail
        self.sessionID = sessionID
        self.severityRaw = (severity ?? action.defaultSeverity).rawValue
    }
}
