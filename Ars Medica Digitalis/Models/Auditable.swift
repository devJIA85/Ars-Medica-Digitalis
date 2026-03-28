//
//  Auditable.swift
//  Ars Medica Digitalis
//
//  Protocolo que identifica entidades clínicas auditables.
//  Permite que AuditService opere genéricamente sin conocer
//  cada tipo de entidad.
//

import Foundation

/// Entidad clínica que puede ser registrada en el audit trail.
///
/// Las conformancias se declaran en extensiones de cada modelo
/// para no mezclar responsabilidades en el cuerpo principal del @Model.
protocol Auditable {
    /// UUID de la entidad — debe coincidir con el campo `id` persistido.
    var entityID: UUID { get }
    /// Tipo de entidad para el audit trail.
    var auditEntityType: AuditEntityType { get }
}
