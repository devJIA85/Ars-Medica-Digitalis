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
        let schema = Schema(AppSchemaV4.models)

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
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            #if targetEnvironment(simulator)
            // En simulador suele no haber sesión iCloud activa (CKAccountStatusNoAccount),
            // lo que genera errores de setup y recovery de CloudKit en cada arranque.
            // Persistimos localmente sin sync para mantener un entorno de desarrollo estable.
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            #else
            // CloudKit principal del usuario en dispositivo real.
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            #endif
        }

        do {
            let container = try ModelContainer(
                for: schema,
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
            logger.critical("ModelContainer creation failed: \(describedError(error), privacy: .private)")

            // Intentar con almacenamiento en memoria como fallback de emergencia.
            // La app podrá usarse, pero los datos de esta sesión no se sincronizarán
            // ni persistirán. ContentView muestra un aviso al usuario si este flag está activo.
            // El contenedor in-memory no tiene store que migrar — no pasar migrationPlan
            // para evitar que la validación del plan bloquee el fallback de emergencia.
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            var fallbackErrorDescription: String = "sin detalle"
            do {
                let fallback = try ModelContainer(for: schema, configurations: [fallbackConfig])
                Ars_Medica_DigitalisApp.isDatabaseUnavailable = true
                return fallback
            } catch {
                fallbackErrorDescription = describedError(error)
                logger.critical(
                    "ModelContainer in-memory fallback failed: \(describedError(error), privacy: .private)"
                )
            }

            // Si ni el contenedor en memoria funciona, el entorno está completamente roto.
            let schemaDiagnosis = diagnoseSchemaIssue()
            fatalError(
                "No se pudo crear el ModelContainer. Error inicial: \(describedError(error)). " +
                "Error fallback in-memory: \(fallbackErrorDescription). " +
                "Diagnóstico de schema: \(schemaDiagnosis)"
            )
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedColorScheme)
                .tint(resolvedThemeColor)
                .environment(\.securityPreferences, securityPreferences)
                .environment(\.auditService, auditService)
                // TODO: [BLOQUEANTE — producción] Inyectar currentActorID con el ID real del
                // Professional autenticado antes de publicar en el App Store.
                // Sin esto, todos los registros de audit trail quedan atribuidos a "system"
                // en lugar del profesional específico, perdiendo trazabilidad clínica.
                // Punto de inyección: resolver `professionals.first?.id.uuidString` y pasar
                // via `.environment(\.currentActorID, id)` desde el nivel raíz de navegación
                // donde el Professional ya está resuelto.
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Ars_Medica_DigitalisApp.removeStaleExportedPDFs()
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

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

    // MARK: - PDF export TTL cleanup

    /// Elimina archivos PDF exportados que hayan superado el TTL de retención.
    ///
    /// Se invoca cada vez que la app pasa a primer plano (`scenePhase == .active`).
    /// Actúa como red de seguridad para el caso en que `onDismiss` del share sheet
    /// no se ejecutó (crash, UIKit sheet, etc.).
    ///
    /// Criterio: archivos `*.pdf` en el directorio Documents con
    /// `creationDate` anterior a `AuditLogRetentionPolicy.exportedPDFTTL`.
    private static func removeStaleExportedPDFs() {
        let fm = FileManager.default
        guard let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let cutoff = Date().addingTimeInterval(-AuditLogRetentionPolicy.exportedPDFTTL)

        let enumerator = fm.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [.creationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "pdf" else { continue }

            guard
                let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .isRegularFileKey]),
                values.isRegularFile == true,
                let creationDate = values.creationDate,
                creationDate < cutoff
            else { continue }

            do {
                try fm.removeItem(at: fileURL)
                logger.info("Removed stale exported PDF")
            } catch {
                logger.warning("Failed to remove stale PDF: \(error, privacy: .private)")
            }
        }
    }

    /// Representación compacta del error y su cadena subyacente.
    private static func describedError(_ error: Error) -> String {
        var parts: [String] = []
        var current: NSError? = error as NSError
        var depth = 0

        while let nsError = current, depth < 4 {
            parts.append("\(nsError.domain)(\(nsError.code)): \(nsError.localizedDescription)")
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }

        return parts.joined(separator: " -> ")
    }

    /// Intenta aislar el modelo (o combinación mínima) que rompe el schema.
    private static func diagnoseSchemaIssue() -> String {
        let allModels = AppSchemaV4.models
        let allModelNames = allModels.map { String(describing: $0) }.joined(separator: ", ")

        // 1) Validación individual por modelo.
        for model in allModels {
            let modelName = String(describing: model)
            let schema = Schema([model])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )

            do {
                _ = try ModelContainer(for: schema, configurations: [config])
            } catch {
                return "Falla con modelo individual '\(modelName)': \(describedError(error))"
            }
        }

        // 2) Validación incremental por prefijos del schema.
        var prefix: [any PersistentModel.Type] = []
        for model in allModels {
            prefix.append(model)
            let schema = Schema(prefix)
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )

            do {
                _ = try ModelContainer(for: schema, configurations: [config])
            } catch {
                let lastModel = String(describing: model)
                let prefixNames = prefix.map { String(describing: $0) }.joined(separator: ", ")
                return "Falla al agregar '\(lastModel)'. Prefijo: [\(prefixNames)]. Error: \(describedError(error))"
            }
        }

        return "No se pudo aislar con validación individual/incremental. Modelos: [\(allModelNames)]"
    }
}
