//
//  Ars_Medica_DigitalisApp.swift
//  Ars Medica Digitalis
//
//  Created by Juan Ignacio Antolini on 18/02/2026.
//

import SwiftUI
import SwiftData
import CoreData
import OSLog

@main
struct Ars_Medica_DigitalisApp: App {

    private static let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "AppLaunch")

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

    /// Flag para alertar a ContentView que la base de datos no pudo inicializarse
    /// correctamente y se está usando un contenedor en memoria temporario.
    static var isDatabaseUnavailable: Bool = false

    @State private var securityPreferences = SecurityPreferenceStore()
    @State private var auditService = AuditService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(AppSchemaV3.models)

        let launchArguments = ProcessInfo.processInfo.arguments
        let isOnboardingUITest = launchArguments.contains(LaunchArgument.onboardingUITest)
        let isProfileDashboardUITest = launchArguments.contains(LaunchArgument.profileDashboardUITest)
        let isScalesUITest = launchArguments.contains(LaunchArgument.scalesUITest)
        let isUITestLaunch = isOnboardingUITest || isProfileDashboardUITest || isScalesUITest

        // La preferencia de biometría vive en Keychain (SecurityPreferenceStore).
        // En tests con almacenamiento in-memory se gestiona a través del store
        // inyectado en el entorno — no se toca UserDefaults ni Keychain aquí.

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
                migrationPlan: AppMigrationPlan.self,
                configurations: [modelConfiguration]
            )

            // Aplica protección de archivo al nivel máximo compatible con CloudKit.
            // .completeFileProtectionUnlessOpen permite que CloudKit acceda en background
            // mientras mantiene el archivo cifrado cuando la app está cerrada y el
            // dispositivo bloqueado.
            if isUITestLaunch == false {
                let dbURL = modelConfiguration.url
                do {
                    try (dbURL as NSURL).setResourceValue(
                        FileProtectionType.completeUnlessOpen,
                        forKey: .fileProtectionKey
                    )
                } catch {
                    logger.warning("DB file protection setup failed: \(error, privacy: .private)")
                }
                observeCloudKitSync()
            }

            if isProfileDashboardUITest {
                seedProfileDashboardUITestDataIfNeeded(in: container.mainContext)
            }

            if isScalesUITest {
                seedScalesUITestDataIfNeeded(in: container.mainContext)
            }

            return container
        } catch {
            logger.critical("ModelContainer creation failed: \(error, privacy: .private)")

            // Intentar con almacenamiento en memoria como fallback de emergencia.
            // La app podrá usarse, pero los datos de esta sesión no se sincronizarán
            // ni persistirán. ContentView muestra un aviso al usuario si este flag está activo.
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [fallbackConfig]) {
                Ars_Medica_DigitalisApp.isDatabaseUnavailable = true
                return fallback
            }

            // Si ni el contenedor en memoria funciona, el entorno está completamente roto.
            fatalError("No se pudo crear el ModelContainer ni en memoria: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedColorScheme)
                .tint(resolvedThemeColor)
                .environment(\.securityPreferences, securityPreferences)
                .environment(\.auditService, auditService)
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

    /// Observa eventos de sincronización de CloudKit y registra errores en el log.
    /// SwiftData delega en NSPersistentCloudKitContainer internamente; el evento
    /// incluye el tipo de operación (import/export/mirror) y el error si lo hubo.
    /// El guard estático evita registrar múltiples observers si el contenedor
    /// se recrea (p.ej. durante migración o recuperación de errores).
    private static var isObservingCloudKit = false

    private static func observeCloudKitSync() {
        guard !isObservingCloudKit else { return }
        isObservingCloudKit = true

        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }

            // Filtrar por tipo: .setup genera ruido en arranque normal sin ser accionable.
            // Solo se loguean import y export, que indican transferencia real de datos clínicos.
            guard event.type == .import || event.type == .export else { return }

            if let error = event.error {
                logger.error(
                    "CloudKit sync error [type=\(event.type.rawValue, privacy: .public)]: \(error, privacy: .private)"
                )
            }
        }
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
            logger.error("No se pudo seedear resultado de escala UI test: \(error.localizedDescription, privacy: .private)")
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
            logger.error("No se pudieron seedear datos UI test: \(error.localizedDescription, privacy: .private)")
        }

        return patient
    }
}
