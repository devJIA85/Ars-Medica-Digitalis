//
//  AuditLogPurgeService.swift
//  Ars Medica Digitalis
//
//  Purga periódica de registros AuditLog vencidos según AuditLogRetentionPolicy.
//  Ejecutar en foreground (scenePhase == .active) una vez por semana como máximo.
//

import Foundation
import SwiftData
import OSLog

/// Elimina entradas `AuditLog` anteriores al umbral de retención de 15 años.
///
/// ## Política
/// La ley 25.326 y la Ley 17.132 argentina exigen retención mínima de 10 años
/// para datos personales y registros médicos. AMD usa 15 años como margen de
/// seguridad. Los registros más antiguos pueden eliminarse sin riesgo normativo.
///
/// ## Frecuencia
/// `purgeIfNeeded(in:)` verifica si transcurrió más de una semana desde la
/// última ejecución exitosa y solo actúa en ese caso. El estado se persiste
/// en `UserDefaults` (clave `auditLog.lastPurgeDateInterval`).
///
/// ## Atomicidad
/// Cada lote de eliminación llama a `context.save()` de forma explícita.
/// Si el save falla, el error se registra en OSLog y la purga se pospone
/// hasta la próxima ejecución. La operación es idempotente.
@MainActor
enum AuditLogPurgeService {

    private static let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "AuditLogPurge")
    private static let lastPurgeDateKey = "auditLog.lastPurgeDateInterval"
    private static let purgeIntervalDays = 7

    // MARK: - API pública

    /// Ejecuta la purga solo si transcurrió más de `purgeIntervalDays` desde la última ejecución.
    /// Llamar en `scenePhase == .active` dentro del App.
    static func purgeIfNeeded(in context: ModelContext) {
        guard shouldPurge() else { return }

        do {
            let count = try purgeExpiredLogs(in: context)
            markPurgeComplete()
            logger.info("AuditLog purge: \(count, privacy: .public) registros eliminados.")
        } catch {
            logger.error("AuditLog purge falló — se reintentará en el próximo ciclo: \(error, privacy: .public)")
        }
    }

    // MARK: - Internos

    @discardableResult
    static func purgeExpiredLogs(in context: ModelContext) throws -> Int {
        let cutoff = AuditLogRetentionPolicy.auditLogRetentionCutoff
        var descriptor = FetchDescriptor<AuditLog>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        // Límite por lote para no saturar memoria con bases de datos muy grandes.
        descriptor.fetchLimit = 1_000

        let expired = try context.fetch(descriptor)
        guard !expired.isEmpty else { return 0 }

        for entry in expired {
            context.delete(entry)
        }
        try context.save()
        return expired.count
    }

    private static func shouldPurge() -> Bool {
        let lastInterval = UserDefaults.standard.double(forKey: lastPurgeDateKey)
        guard lastInterval > 0 else { return true }
        let lastPurge = Date(timeIntervalSince1970: lastInterval)
        guard let threshold = Calendar.current.date(byAdding: .day, value: -purgeIntervalDays, to: .now) else {
            return true
        }
        return lastPurge < threshold
    }

    private static func markPurgeComplete() {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: lastPurgeDateKey)
    }
}
