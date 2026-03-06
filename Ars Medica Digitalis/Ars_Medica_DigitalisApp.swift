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

    private enum LaunchArgument {
        static let onboardingUITest = "UITEST_ONBOARDING"
    }

    /// Preferencia de apariencia local (por dispositivo, no se sincroniza vía CloudKit).
    /// Valores posibles: "system", "light", "dark".
    @AppStorage("appearance.colorScheme") private var colorSchemePreference: String = "system"

    /// Color de acento elegido por el profesional. Se aplica como tint global.
    @AppStorage("appearance.themeColor") private var themeColorRaw: String = AppThemeColor.blue.rawValue

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
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
        ])

        let launchArguments = ProcessInfo.processInfo.arguments
        let isOnboardingUITest = launchArguments.contains(LaunchArgument.onboardingUITest)

        // En UI tests de onboarding usamos almacenamiento en memoria para
        // garantizar estado vacío y flujo determinista.
        let modelConfiguration: ModelConfiguration
        if isOnboardingUITest {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            // cloudKitDatabase: .automatic habilita sincronización con la zona privada
            // de iCloud del usuario. Requiere el entitlement de CloudKit configurado en Xcode.
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
        }

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
                .tint(resolvedThemeColor)
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

    /// Resuelve el color de tema desde el string persistido.
    private var resolvedThemeColor: Color {
        (AppThemeColor(rawValue: themeColorRaw) ?? .blue).color
    }
}
