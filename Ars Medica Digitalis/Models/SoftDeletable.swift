//
//  SoftDeletable.swift
//  Ars Medica Digitalis
//
//  Protocolo para modelos que implementan borrado lógico.
//  El borrado físico está prohibido en AMD porque la historia clínica
//  es un documento médico-legal que CloudKit debe conservar sin excepciones.
//
//  Aplicar este protocolo al declarar un modelo garantiza que el compilador
//  exija las propiedades de auditoría y expone softDelete()/restore() como
//  API uniforme, evitando que futuros cambios usen context.delete() por error.
//

import Foundation

/// Contrato de borrado lógico para entidades que no pueden eliminarse físicamente.
protocol SoftDeletable: AnyObject {
    /// Fecha de baja lógica. nil = registro activo, non-nil = inactivo.
    var deletedAt: Date? { get set }
    /// Timestamp de última modificación — requerido para que softDelete/restore
    /// lo actualicen siempre de forma consistente.
    var updatedAt: Date { get set }
}

extension SoftDeletable {

    /// Indica si la entidad está activa (no fue dada de baja).
    var isActive: Bool { deletedAt == nil }

    /// Marca la entidad como inactiva registrando la fecha de baja.
    /// Actualiza updatedAt para que el token de refresco del dashboard
    /// detecte el cambio en el mismo ciclo de render.
    func softDelete() {
        let now = Date()
        deletedAt = now
        updatedAt = now
    }

    /// Restaura una entidad dada de baja limpiando deletedAt.
    /// Actualiza updatedAt para propagar el cambio al token de refresco.
    func restore() {
        deletedAt = nil
        updatedAt = Date()
    }
}
