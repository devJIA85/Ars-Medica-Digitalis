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
