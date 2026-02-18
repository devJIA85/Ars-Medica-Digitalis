//
//  Ars_Medica_DigitalisApp.swift
//  Ars Medica Digitalis
//
//  Created by Juan Ignacio Antolini on 18/02/2026.
//

import SwiftUI
import SwiftData

@main
struct Ars_Medica_DigitalisApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Professional.self,
            Patient.self,
            Session.self,
            Diagnosis.self,
            Attachment.self,
        ])

        // cloudKitDatabase: .automatic habilita sincronización con la zona privada
        // de iCloud del usuario. Requiere el entitlement de CloudKit configurado en Xcode.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
