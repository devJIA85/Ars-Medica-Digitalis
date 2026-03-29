//
//  AuditLogRetentionPolicy.swift
//  Ars Medica Digitalis
//
//  Política de retención de datos del audit trail y archivos exportados.
//
//  ## Filosofía de diseño
//  Los valores de retención se concentran aquí para que cualquier ajuste
//  (legal, compliance, auditoría externa) se refleje en un solo lugar.
//  No dispersar TTLs o umbrales en llamadas ad-hoc.
//

import Foundation

/// Constantes de retención para el audit trail clínico y archivos exportados.
///
/// ## Contexto normativo
/// La ley argentina 25.326 (Protección de Datos Personales) y las normativas
/// de registros médicos exigen conservar documentación clínica por un mínimo
/// de 10 años. Los valores de `auditLogRetentionYears` y
/// `exportedPDFTTL` reflejan esta restricción.
///
/// ## Uso
/// Leer las constantes desde cualquier capa; nunca hardcodear duraciones
/// directamente en el código de producción.
enum AuditLogRetentionPolicy {

    // MARK: - Audit trail

    /// Años mínimos de retención de registros `AuditLog`.
    ///
    /// Valor: 10 años (requisito legal mínimo en Argentina para registros médicos).
    /// Los registros más antiguos pueden archivarse o exportarse antes de eliminarse,
    /// pero nunca deben borrarse antes de este umbral.
    ///
    /// - Note: SwiftData + CloudKit no implementa eliminación automática.
    ///   La purga debe ejecutarse de forma explícita y auditada.
    static let auditLogRetentionYears: Int = 10

    /// Fecha mínima de retención calculada desde `Date.now`.
    static var auditLogRetentionCutoff: Date {
        Calendar.current.date(
            byAdding: .year,
            value: -auditLogRetentionYears,
            to: .now
        ) ?? .distantPast
    }

    // MARK: - PDF exportado

    /// Tiempo máximo (en segundos) que un PDF exportado puede permanecer
    /// en el directorio Documents antes de ser eliminado automáticamente.
    ///
    /// Valor: 1 hora (3600 s).
    /// Justificación: los PDFs exportados son copias temporales para compartir;
    /// no deben persistir más tiempo del necesario para completar la operación.
    /// El `onDismiss` del share sheet elimina el archivo inmediatamente;
    /// este TTL actúa como red de seguridad para crashes o sheets de UIKit.
    static let exportedPDFTTL: TimeInterval = 3_600
}
