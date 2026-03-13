//
//  SoftDeletable.swift
//  Ars Medica Digitalis
//
//  Protocolo para modelos que implementan borrado lógico.
//  El borrado físico está prohibido en AMD porque la historia clínica
//  es un documento médico-legal que CloudKit debe conservar sin excepciones.
//
//  Aplicar este protocolo al declarar un modelo garantiza que el compilador
//  exija la propiedad deletedAt y expone softDelete() como API uniforme,
//  evitando que futuros cambios usen context.delete() por error.
//

import Foundation

/// Contrato de borrado lógico para entidades que no pueden eliminarse físicamente.
protocol SoftDeletable: AnyObject {
    /// Fecha de baja lógica. nil = registro activo, non-nil = inactivo.
    var deletedAt: Date? { get set }
}

extension SoftDeletable {

    /// Indica si la entidad está activa (no fue dada de baja).
    var isActive: Bool { deletedAt == nil }

    /// Marca la entidad como inactiva registrando la fecha de baja.
    /// Usar siempre este método en lugar de asignar deletedAt directamente
    /// para que el intent quede claro en los diffs del historial.
    func softDelete() {
        deletedAt = Date()
    }
}
