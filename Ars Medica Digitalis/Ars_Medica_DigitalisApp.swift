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

    /// Preferencia de apariencia local (por dispositivo, no se sincroniza vía CloudKit).
    /// Valores posibles: "system", "light", "dark".
    @AppStorage("appearance.colorScheme") private var colorSchemePreference: String = "system"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Professional.self,
            Patient.self,
            Session.self,
            Diagnosis.self,
            Attachment.self,
            PriorTreatment.self,
            Hospitalization.self,
            AnthropometricRecord.self,
            ICD11Entry.self,
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
                .preferredColorScheme(resolvedColorScheme)
        }
        .modelContainer(sharedModelContainer)
    }

    /// Resuelve la preferencia de string a ColorScheme opcional.
    /// nil = seguir la configuración del sistema operativo.
    private var resolvedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}
