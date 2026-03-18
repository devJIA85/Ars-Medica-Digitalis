//
//  AppSchema.swift
//  Ars Medica Digitalis
//
//  Registro central del esquema SwiftData.
//  Centraliza la lista de modelos persistentes del dominio.
//
//  Cuando necesites una migración real entre versiones:
//    1. Crear enum AppSchemaV2: VersionedSchema con los modelos actualizados.
//    2. Crear un SchemaMigrationPlan con schemas [V1, V2] y stages.
//    3. Pasar migrationPlan al ModelContainer en App.
//

import SwiftData

// MARK: - Esquema actual

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
