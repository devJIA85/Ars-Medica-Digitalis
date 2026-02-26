//
//  ModelContainer+Preview.swift
//  Ars Medica Digitalis
//
//  Helpers compartidos para previews SwiftUI.
//

import SwiftData

extension ModelContainer {
    /// Lista de modelos del schema principal para previews en memoria.
    static var previewSchema: [any PersistentModel.Type] {
        [
            Professional.self,
            Patient.self,
            Session.self,
            Diagnosis.self,
            Attachment.self,
            PriorTreatment.self,
            Hospitalization.self,
            AnthropometricRecord.self,
            ICD11Entry.self,
            Medication.self,
        ]
    }

    /// Container en memoria para previews con el schema completo.
    static var preview: ModelContainer {
        let schema = Schema(previewSchema)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
}
