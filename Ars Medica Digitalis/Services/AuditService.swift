//
//  AuditService.swift
//  Ars Medica Digitalis
//
//  Servicio centralizado de audit trail clínico.
//  Solo inserta entradas — el save es responsabilidad del caller.
//

import Foundation
import OSLog
import SwiftData
import SwiftUI

/// Registra acciones críticas sobre datos clínicos en el audit trail.
///
/// ## Responsabilidades
/// - `context.insert(AuditLog)` — única operación que ejecuta.
/// - Nunca llama `context.save()` — la atomicidad es responsabilidad del caller.
///
/// ## Garantía de atomicidad
/// La entidad mutada/insertada y el AuditLog deben quedar en el mismo save.
/// El caller debe:
///   1. Ejecutar la mutación de la entidad.
///   2. Llamar `log()` con el mismo `ModelContext`.
///   3. Llamar `do { try context.save() } catch { ... }` inmediatamente después.
/// Los tres pasos son sincrónicos en MainActor — nunca hay un autosave intermedio.
///
/// ## Auditoría de lectura (read)
/// Cada evento `.read` genera un `context.insert()` + `context.save()`, es decir,
/// una escritura. Esto es intencional: el requisito de trazabilidad de accesos a
/// datos clínicos sensibles tiene prioridad sobre el costo de I/O.
/// Si en el futuro el volumen de logs de lectura genera presión en CloudKit,
/// evaluar batching o sampling — por ahora se loguea cada acceso.
///
/// ## Actor del log
/// `performedBy` debe recibir `currentActorID` desde el entorno (ver abajo).
/// Default "system" solo como fallback hasta que el professional esté disponible.
///
/// ## Deuda técnica
/// El logging actualmente vive en las Views para acceder al `ModelContext` sin
/// infraestructura adicional. Migrar a ViewModel/Coordinator cuando se centralice
/// el acceso al contexto.
@Observable
final class AuditService {

    // MARK: - Missing-actor detection

    /// Número de veces que se registró un log sin actor inyectado en esta sesión.
    /// Observable: cualquier vista o monitor puede reaccionar a este contador
    /// sin necesidad de infraestructura adicional.
    private(set) var missingActorCount: Int = 0

    private static let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "AuditService")

    // MARK: - Logging

    /// Registra una acción clínica en el audit trail.
    /// - Parameters:
    ///   - action: Tipo de acción ejecutada.
    ///   - entity: Entidad afectada — debe conformar `Auditable`.
    ///   - context: ModelContext activo en la capa de llamada. Debe ser el mismo
    ///     que se usó para la mutación, para garantizar atomicidad.
    ///   - actor: ID del professional activo. Leer de `EnvironmentValues.currentActorID`.
    ///   - detail: Contexto adicional opcional (ej. código CIE-11, campo modificado).
    ///   - sessionID: ID de sesión clínica relacionada, si aplica.
    ///   - severity: Nivel de criticidad. Por defecto derivado de `action.defaultSeverity`.
    func log(
        action: AuditAction,
        on entity: some Auditable,
        in context: ModelContext,
        performedBy actor: String = "unknown_actor",
        detail: String? = nil,
        sessionID: UUID? = nil,
        severity: AuditSeverity? = nil
    ) {
        if actor == "unknown_actor" {
            // .fault garantiza visibilidad en Console.app incluso con nivel de log reducido.
            // No se interrumpe la operación: el registro se persiste con el sentinel
            // para mantener la integridad del trail.
            AuditService.logger.fault(
                "Audit log without actor injection [action=\(action.rawValue, privacy: .public), entity=\(entity.auditEntityType.rawValue, privacy: .public)]"
            )
            missingActorCount += 1
        }

        let entry = AuditLog(
            action: action,
            entityType: entity.auditEntityType,
            entityID: entity.entityID,
            performedBy: actor,
            detail: detail,
            sessionID: sessionID,
            severity: severity
        )
        context.insert(entry)
    }

    // MARK: - Consultas

    /// Devuelve todos los eventos del audit trail para una entidad específica,
    /// ordenados por fecha descendente.
    @MainActor
    func events(
        for entityID: UUID,
        in context: ModelContext
    ) throws -> [AuditLog] {
        var descriptor = FetchDescriptor<AuditLog>(
            predicate: #Predicate { $0.entityID == entityID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        return try context.fetch(descriptor)
    }

    /// Devuelve todos los eventos de un tipo de acción específico,
    /// ordenados por fecha descendente.
    @MainActor
    func events(
        action: AuditAction,
        in context: ModelContext
    ) throws -> [AuditLog] {
        let rawValue = action.rawValue
        var descriptor = FetchDescriptor<AuditLog>(
            predicate: #Predicate { $0.actionRaw == rawValue },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        return try context.fetch(descriptor)
    }

    /// Devuelve todos los eventos dentro de una ventana temporal,
    /// ordenados por fecha descendente.
    @MainActor
    func events(
        from startDate: Date,
        to endDate: Date,
        in context: ModelContext
    ) throws -> [AuditLog] {
        var descriptor = FetchDescriptor<AuditLog>(
            predicate: #Predicate { $0.timestamp >= startDate && $0.timestamp <= endDate },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1000
        return try context.fetch(descriptor)
    }
}

// MARK: - Environment: AuditService

private struct AuditServiceKey: EnvironmentKey {
    // nonisolated(unsafe): el valor por defecto se crea una sola vez al arrancar
    // y siempre se sobreescribe con la instancia real inyectada desde App.
    nonisolated(unsafe) static let defaultValue = AuditService()
}

extension EnvironmentValues {
    var auditService: AuditService {
        get { self[AuditServiceKey.self] }
        set { self[AuditServiceKey.self] = newValue }
    }
}

// MARK: - Environment: currentActorID

/// ID del professional activo, usado como actor en el audit trail.
///
/// ## Punto de inyección
/// Debe inyectarse desde el nivel de navegación donde el Professional
/// está resuelto (ej. ContentView o el NavigationStack raíz):
///
///     .environment(\.currentActorID, professional.id.uuidString)
///
/// ## Fallback
/// El valor por defecto es `"unknown_actor"` — sentinel explícito que indica
/// que la inyección no ocurrió. Es distinto de `"system"` (acciones internas
/// de la app) para facilitar la detección en auditorías:
/// cualquier registro con `performedBy == "unknown_actor"` señala un punto
/// del código donde falta la inyección del actor real.
private struct CurrentActorIDKey: EnvironmentKey {
    static let defaultValue: String = "unknown_actor"
}

extension EnvironmentValues {
    var currentActorID: String {
        get { self[CurrentActorIDKey.self] }
        set { self[CurrentActorIDKey.self] = newValue }
    }
}
