//
//  AppSchema.swift
//  Ars Medica Digitalis
//
//  Registro central del esquema SwiftData y el plan de migración entre versiones.
//
//  Historial de versiones:
//  V1 (1.0.0) — Esquema original. Patient.activeDiagnoses como relación cruda.
//  V2 (2.0.0) — Renombre: Patient.activeDiagnoses → Patient.allDiagnoses.
//               Diagnoses, PriorTreatments, Hospitalizations ganan campos SoftDeletable
//               (deletedAt, updatedAt, deletedBy, deletionReason).
//               Patient gana deletedBy, deletionReason.
//               La migración V1→V2 es un no-op de datos: la relación many-side
//               vive en Diagnosis.patient (foreign key en la tabla Diagnosis),
//               no en Patient.allDiagnoses, por lo que no hay datos que mover.
//  V3 (3.0.0) — Agrega AuditLog para audit trail clínico (append-only).
//               Migración V2→V3 es lightweight: nueva tabla sin cambios en
//               entidades existentes.
//
//  Agregar versiones futuras:
//    1. Crear AppSchemaVN con versionIdentifier incrementado.
//    2. Agregar un nuevo MigrationStage en AppMigrationPlan.
//    3. Actualizar App para usar Schema(AppSchemaVN.models).
//

import SwiftData

// MARK: - Schema V1 (legado — solo para migración)

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Professional.self,
            PricingAdjustmentPolicy.self,
            Patient.self,
            Session.self,
            SessionCatalogType.self,
            SessionTypePriceVersion.self,
            PatientCurrencyVersion.self,
            PatientSessionDefaultPrice.self,
            Payment.self,
            Diagnosis.self,
            Attachment.self,
            PriorTreatment.self,
            Hospitalization.self,
            AnthropometricRecord.self,
            ICD11Entry.self,
            Medication.self,
            PatientScaleResult.self,
        ]
    }
}

// MARK: - Schema V2 (anterior)

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        AppSchemaV1.models   // mismos tipos — Patient actualizado en su .swift
    }
}

// MARK: - Schema V3 (actual)

enum AppSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        AppSchemaV2.models + [AuditLog.self]
    }
}

// MARK: - Plan de migración

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        AppSchemaV1.self,
        AppSchemaV2.self,
        AppSchemaV3.self,
    ]
    static var stages: [MigrationStage] = [v1ToV2, v2ToV3]

    /// Migración V1 → V2: no-op de datos.
    /// SwiftData necesita conocer el cambio de versión para no rechazar
    /// el store existente, pero no hay datos que mover:
    /// la relación many-side (Diagnosis.patient) no se renombró.
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self,
        willMigrate: nil,
        didMigrate: nil
    )

    /// Migración V2 → V3: lightweight, solo agrega la tabla AuditLog.
    /// No hay datos que migrar en las entidades existentes.
    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: AppSchemaV2.self,
        toVersion: AppSchemaV3.self
    )
}
