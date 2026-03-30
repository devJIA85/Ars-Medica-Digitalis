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
    /// Valor: 15 años.
    /// La ley argentina 25.326 establece un mínimo de 10 años para datos personales,
    /// pero la normativa de registros médicos (Ley 17.132 y resoluciones del Ministerio
    /// de Salud) y buenas prácticas internacionales (HIPAA, HL7) recomiendan 15 años
    /// para historia clínica computarizada. Se adopta el valor más conservador para
    /// maximizar la trazabilidad clínica y cubrir eventuales cambios normativos.
    ///
    /// - Note: SwiftData + CloudKit no implementa eliminación automática.
    ///   La purga debe ejecutarse de forma explícita y auditada.
    static let auditLogRetentionYears: Int = 15

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
    /// Valor: 24 horas (86 400 s).
    /// Justificación: los PDFs exportados son copias temporales para compartir.
    /// En contexto clínico el profesional puede necesitar abrir la app, generar
    /// el PDF y enviarlo en momentos distintos dentro de una jornada de trabajo.
    /// 24 h da margen operativo sin comprometer la minimización de datos.
    /// El `onDismiss` del share sheet elimina el archivo inmediatamente;
    /// este TTL actúa como red de seguridad para crashes o sheets de UIKit.
    static let exportedPDFTTL: TimeInterval = 86_400
}
