//
//  AppSchema.swift
//  Ars Medica Digitalis
//
//  Registro central del schema SwiftData vigente.
//  Nota: se removió el plan de migración versionado legacy porque reutilizaba
//  los mismos @Model entre versiones históricas, lo que puede provocar
//  "Duplicate version checksums detected".
//

import SwiftData

/// Lista canónica de modelos persistentes del build actual.
enum AppSchemaCurrent {
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
            AuditLog.self,
        ]
    }
}

/// Versión de schema actual para compatibilidad de referencias existentes.
enum AppSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        AppSchemaCurrent.models
    }
}

/// Plan de migración que establece V4 como línea base del schema.
///
/// ## Por qué solo existe V4
/// Las versiones anteriores (V1–V3) usaban los mismos @Model del build actual,
/// lo que generaba "Duplicate version checksums" en SwiftData. En lugar de
/// duplicar clases con snapshots históricos (práctica correcta pero costosa en
/// retrospectiva), se declara V4 como origen histórico del plan.
///
/// ## Consecuencia
/// - Stores que ya están en V4: no requieren migración → sin impacto.
/// - Stores en V1–V3: SwiftData no puede resolver la ruta de migración y lanza.
///   El caller (Ars_Medica_DigitalisApp) captura el error y avisa al usuario.
/// - Stores nuevos: arrancan directamente en V4 → correcto.
///
/// ## Próximo paso al agregar V5
/// Agregar `AppSchemaV5` a `schemas` y definir la etapa de migración V4 → V5
/// antes de subir al App Store.
enum AppSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV4.self] }
    static var stages: [MigrationStage] { [] }
}
