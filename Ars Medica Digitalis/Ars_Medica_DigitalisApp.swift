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
        static let profileDashboardUITest = "UITEST_PROFILE_DASHBOARD"
        static let scalesUITest = "UITEST_SCALES"
    }

    /// Preferencia de apariencia local (por dispositivo, no se sincroniza vía CloudKit).
    /// Valores posibles: "system", "light", "dark".
    @AppStorage("appearance.colorScheme") private var colorSchemePreference: String = "system"

    /// Color de acento elegido por el profesional. Se aplica como tint global.
    @AppStorage("appearance.themeColor") private var themeColorRaw: String = AppThemeColor.blue.rawValue

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(AppSchemaV1.models)

        let launchArguments = ProcessInfo.processInfo.arguments
        let isOnboardingUITest = launchArguments.contains(LaunchArgument.onboardingUITest)
        let isProfileDashboardUITest = launchArguments.contains(LaunchArgument.profileDashboardUITest)
        let isScalesUITest = launchArguments.contains(LaunchArgument.scalesUITest)
        let isUITestLaunch = isOnboardingUITest || isProfileDashboardUITest || isScalesUITest

        if isUITestLaunch {
            UserDefaults.standard.set(false, forKey: "security.biometricEnabled")
        }

        // En UI tests de onboarding usamos almacenamiento en memoria para
        // garantizar estado vacío y flujo determinista.
        let modelConfiguration: ModelConfiguration
        if isUITestLaunch {
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
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            if isProfileDashboardUITest {
                seedProfileDashboardUITestDataIfNeeded(in: container.mainContext)
            }

            if isScalesUITest {
                seedScalesUITestDataIfNeeded(in: container.mainContext)
            }

            return container
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

    private static func seedProfileDashboardUITestDataIfNeeded(in context: ModelContext) {
        _ = seedUITestPatientIfNeeded(in: context)
    }

    private static func seedScalesUITestDataIfNeeded(in context: ModelContext) {
        let patient = seedUITestPatientIfNeeded(in: context)

        let descriptor = FetchDescriptor<PatientScaleResult>()
        if let existing = try? context.fetch(descriptor),
           existing.contains(where: { $0.patientID == patient.id && $0.scaleID == "BDI-II" }) {
            return
        }

        let result = PatientScaleResult(
            patientID: patient.id,
            scaleID: "BDI-II",
            date: Date().addingTimeInterval(-3_600),
            totalScore: 32,
            severity: "severe",
            answers: []
        )
        context.insert(result)

        do {
            try context.save()
        } catch {
            assertionFailure("No se pudo seedear resultado de escala UI test: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private static func seedUITestPatientIfNeeded(in context: ModelContext) -> Patient {
        let descriptor = FetchDescriptor<Professional>()
        if let existing = try? context.fetch(descriptor), let professional = existing.first {
            let patientDescriptor = FetchDescriptor<Patient>()
            if let patients = try? context.fetch(patientDescriptor),
               let existingPatient = patients.first(where: { $0.professional?.id == professional.id }) {
                return existingPatient
            }
        }

        let professional = Professional(
            fullName: "Dra. Test",
            licenseNumber: "MN 99999",
            specialty: "Psicología",
            email: "test@example.com"
        )
        context.insert(professional)

        let patient = Patient(
            firstName: "Paciente",
            lastName: "Demo",
            medicalRecordNumber: "HC-00000001",
            professional: professional
        )
        context.insert(patient)

        let session = Session(
            sessionDate: Date().addingTimeInterval(-86_400),
            status: SessionStatusMapping.completada.rawValue,
            patient: patient
        )
        context.insert(session)

        do {
            try context.save()
        } catch {
            assertionFailure("No se pudieron seedear datos UI test: \(error.localizedDescription)")
        }

        return patient
    }
}
