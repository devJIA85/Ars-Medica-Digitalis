//
//  AuditService.swift
//  Ars Medica Digitalis
//
//  Servicio centralizado de audit trail clínico.
//  Solo inserta entradas — el save es responsabilidad del caller.
//

import Foundation
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
///   3. Llamar `try? context.save()` inmediatamente después.
/// Los tres pasos son sincrónicos en MainActor — nunca hay un autosave intermedio.
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

    // MARK: - API pública

    /// Registra una acción clínica en el audit trail.
    /// - Parameters:
    ///   - action: Tipo de acción ejecutada.
    ///   - entity: Entidad afectada — debe conformar `Auditable`.
    ///   - context: ModelContext activo en la capa de llamada. Debe ser el mismo
    ///     que se usó para la mutación de la entidad, para garantizar atomicidad.
    ///   - actor: ID del professional activo. Leer de `EnvironmentValues.currentActorID`.
    ///   - detail: Contexto adicional opcional (ej. código CIE-11, campo modificado).
    func log(
        action: AuditAction,
        on entity: some Auditable,
        in context: ModelContext,
        performedBy actor: String = "system",
        detail: String? = nil
    ) {
        let entry = AuditLog(
            action: action,
            entityType: entity.auditEntityType,
            entityID: entity.entityID,
            performedBy: actor,
            detail: detail
        )
        context.insert(entry)
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
/// Mientras no esté inyectado, el valor es "system" — los logs quedan
/// válidos pero sin atribución a un professional específico.
private struct CurrentActorIDKey: EnvironmentKey {
    static let defaultValue: String = "system"
}

extension EnvironmentValues {
    var currentActorID: String {
        get { self[CurrentActorIDKey.self] }
        set { self[CurrentActorIDKey.self] = newValue }
    }
}
