//
//  ContentView.swift
//  Ars Medica Digitalis
//
//  Created by Juan Ignacio Antolini on 18/02/2026.
//

import OSLog
import SwiftUI
import SwiftData

/// Vista raíz que controla el flujo principal de la app:
/// - Sin Professional → Onboarding (HU-01)
/// - Con Professional → Lista de pacientes (HU-02, HU-03)
struct ContentView: View {

    private let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "LaunchRepair")

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.securityPreferences) private var securityPreferences
    @Query private var professionals: [Professional]
    @AppStorage("repairs.sessionPhantoms.v1") private var didRunSessionPhantomRepair: Bool = false
    /// Namespace para la transición zoom entre la fila de paciente
    /// en la lista y su vista de detalle.
    @Namespace private var patientTransition

    /// Estado para el CTA "Nuevo paciente" desde el top bar.
    @State private var showingNewPatient: Bool = false

    // Flag local para forzar la transición tras completar el onboarding,
    // ya que @Query puede tardar un ciclo en reflejar el insert.
    @State private var didCompleteOnboarding = false
    @State private var didRunLaunchFlow = false
    @State private var launchPhase: LaunchPhase = .splash
    @State private var isAppUnlocked: Bool = true
    @State private var biometricLock = BiometricLockCoordinator()
    @State private var isRunningSessionRepair: Bool = false
    @State private var isRunningPatientRecordRepair: Bool = false
    @State private var didResolveSessionRepairForCurrentLaunch: Bool = false
    @State private var didResolvePatientRecordRepairForCurrentLaunch: Bool = false
    @State private var deepLinkedSessionContext: DeepLinkedSessionContext?
    @State private var searchText: String = ""

    private enum LaunchPhase {
        case splash
        case ready
    }

    private struct DeepLinkedSessionContext: Identifiable {
        let session: Session
        let patient: Patient
        let professional: Professional

        var id: UUID { session.id }
    }

    var body: some View {
        Group {
            switch launchPhase {
            case .splash:
                SplashView()
            case .ready:
                rootContent
                    .overlay(alignment: .top) {
                        if Ars_Medica_DigitalisApp.isDatabaseUnavailable {
                            databaseUnavailableBanner
                        }
                    }
            }
        }
        // Overlay de privacidad aplicado al root Group de ContentView.body.
        // Este nivel cubre toda la jerarquía SwiftUI (toolbars, overlays, sheets
        // presentados con SwiftUI nativo) sin necesidad de envolverlo en WindowGroup.
        //
        // scenePhase != .active cubre .inactive (ej. multitarea, llamada entrante)
        // y .background, más cualquier fase futura desconocida.
        // isAppUnlocked evita duplicar la redacción cuando AppLockView ya está activo.
        //
        // Limitación conocida: las sheets presentadas mediante UIKit directamente
        // (UIActivityViewController, UIDocumentPickerViewController) son ventanas
        // UIKit independientes y no quedan cubiertas por este overlay. Se acepta
        // como limitación del sistema; documentar en el threat model.
        .overlay {
            if scenePhase != .active && isAppUnlocked {
                privacyOverlay
            }
        }
        .task {
            await runLaunchFlowIfNeeded()
        }
        .task(id: professionals.first?.id) {
            await runSessionRepairIfNeeded()
        }
        .task(id: "patient-records-\(professionals.first?.id.uuidString ?? "none")") {
            await runPatientRecordRepairIfNeeded()
        }
        .onChange(of: professionals.first?.id) { _, _ in
            handleProtectionContextChange()
        }
        .onChange(of: securityPreferences.biometricEnabled) { _, isEnabled in
            handleBiometricToggleChange(isEnabled: isEnabled)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onOpenURL { url in
            handleIncomingDeepLink(url)
        }
        .environment(\.currentActorID, resolvedCurrentActorID)
    }

    // MARK: - Vista principal

    @ViewBuilder
    private var rootContent: some View {
        if let professional = professionals.first {
            if didResolveLaunchRepairsForCurrentLaunch == false {
                ProgressView()
            } else if shouldRequireLock && !isAppUnlocked {
                AppLockView(
                    capability: biometricLock.capability,
                    isAuthenticating: biometricLock.isAuthenticating,
                    errorMessage: biometricLock.errorMessage,
                    onUnlockBiometric: {
                        Task { await unlockWithBiometrics() }
                    },
                    onUnlockWithPasscode: {
                        Task { await unlockWithDeviceOwnerAuthentication() }
                    }
                )
            } else {
                mainView(for: professional)
            }
        } else if didCompleteOnboarding {
            // Estado transitorio: el Professional se insertó pero @Query
            // aún no lo refleja. ProgressView evita flash visual.
            ProgressView()
        } else {
            OnboardingView {
                didCompleteOnboarding = true
            }
        }
    }

    private var didResolveLaunchRepairsForCurrentLaunch: Bool {
        didResolveSessionRepairForCurrentLaunch
        && didResolvePatientRecordRepairForCurrentLaunch
        && isRunningSessionRepair == false
        && isRunningPatientRecordRepair == false
    }

    private var resolvedCurrentActorID: String {
        professionals.first?.id.uuidString ?? "system"
    }

    @ViewBuilder
    private func mainView(for professional: Professional) -> some View {
        TabView {
            Tab("Pacientes", systemImage: "person.2") {
                NavigationStack {
                    PatientListView(
                        professional: professional,
                        namespace: patientTransition,
                        onAddPatient: { showingNewPatient = true },
                        enablesSearch: false
                    )
                }
            }

            Tab("Calendario", systemImage: "calendar") {
                NavigationStack {
                    CalendarView(professional: professional)
                }
            }

            Tab("Clínico", systemImage: "chart.bar.xaxis.ascending") {
                NavigationStack {
                    ClinicalDashboardView(professional: professional)
                }
            }

            // Lupa de búsqueda separada en la tab bar (patrón Liquid Glass iOS 26).
            // Al tocarla, la tab bar se transforma en campo de búsqueda.
            Tab(role: .search) {
                NavigationStack {
                    PatientListView(
                        professional: professional,
                        namespace: patientTransition,
                        onAddPatient: { showingNewPatient = true },
                        enablesSearch: false,
                        externalSearchText: searchText
                    )
                    .searchable(text: $searchText, prompt: "Buscar paciente")
                }
            }
        }
        .symbolRenderingMode(.hierarchical)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showingNewPatient) {
            NavigationStack {
                PatientFormView(professional: professional)
            }
        }
        .sheet(item: $deepLinkedSessionContext) { context in
            NavigationStack {
                SessionDetailView(
                    session: context.session,
                    patient: context.patient,
                    professional: context.professional
                )
            }
        }
        .task {
            // Poblar catálogo CIE-11 offline en background (solo primer launch)
            let service = ICD11SeedService(modelContainer: modelContext.container)
            await service.seedIfNeeded()

            // Poblar vademécum local desde CSV (solo primer launch)
            let medicationSeed = MedicationSeedService(modelContainer: modelContext.container)
            await medicationSeed.seedIfNeeded()
        }
    }

    // MARK: - Seguridad y arranque

    private var shouldRequireLock: Bool {
        securityPreferences.biometricEnabled && professionals.first != nil
    }

    @MainActor
    private func runLaunchFlowIfNeeded() async {
        guard !didRunLaunchFlow else { return }
        didRunLaunchFlow = true

        // Splash breve para evitar cambios bruscos al resolver estado inicial.
        try? await Task.sleep(for: .milliseconds(1200))
        launchPhase = .ready

        handleProtectionContextChange()

        if shouldRequireLock && scenePhase == .active {
            await unlockWithBiometrics()
        }
    }

    @MainActor
    private func handleIncomingDeepLink(_ url: URL) {
        guard let sessionID = SessionDeepLink.sessionID(from: url) else {
            return
        }

        guard let professional = professionals.first else {
            return
        }

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.id == sessionID
            }
        )

        guard let resolvedSession = try? modelContext.fetch(descriptor).first,
              let patient = resolvedSession.patient else {
            return
        }

        deepLinkedSessionContext = DeepLinkedSessionContext(
            session: resolvedSession,
            patient: patient,
            professional: professional
        )
    }

    @MainActor
    private func handleProtectionContextChange() {
        biometricLock.refreshCapability()

        if shouldRequireLock {
            isAppUnlocked = false
        } else {
            isAppUnlocked = true
            biometricLock.clearError()
        }
    }

    @MainActor
    private func handleBiometricToggleChange(isEnabled: Bool) {
        if isEnabled {
            biometricLock.refreshCapability()
            guard biometricLock.capability.isAvailable else {
                securityPreferences.biometricEnabled = false
                return
            }

            if professionals.first != nil {
                isAppUnlocked = false
                Task { await unlockWithBiometrics() }
            }
        } else {
            isAppUnlocked = true
            biometricLock.clearError()
        }
    }

    @MainActor
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard shouldRequireLock else { return }

        switch phase {
        case .background:
            isAppUnlocked = false
        case .active:
            guard isAppUnlocked == false, biometricLock.isAuthenticating == false else {
                return
            }
            Task { await unlockWithBiometrics() }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    @MainActor
    private func unlockWithBiometrics() async {
        guard shouldRequireLock else {
            isAppUnlocked = true
            return
        }
        if await biometricLock.authenticateBiometrically() {
            isAppUnlocked = true
        }
    }

    @MainActor
    private func unlockWithDeviceOwnerAuthentication() async {
        guard shouldRequireLock else {
            isAppUnlocked = true
            return
        }
        if await biometricLock.authenticateWithPasscode() {
            isAppUnlocked = true
        }
    }

    /// Ejecuta una limpieza conservadora de sesiones fantasma generadas por
    /// previews antiguos. Corre una sola vez por instalación para no borrar
    /// nada durante el uso normal y para devolver consistencia al calendario.
    @MainActor
    private func runSessionRepairIfNeeded() async {
        guard professionals.first != nil else {
            didResolveSessionRepairForCurrentLaunch = true
            return
        }

        if didRunSessionPhantomRepair {
            didResolveSessionRepairForCurrentLaunch = true
            return
        }

        guard isRunningSessionRepair == false else { return }

        didResolveSessionRepairForCurrentLaunch = false
        isRunningSessionRepair = true
        defer {
            isRunningSessionRepair = false
            didResolveSessionRepairForCurrentLaunch = true
        }

        do {
            let result = try await SessionPhantomRepairService().repairIfNeeded(in: modelContext)
            logger.info("SessionPhantomRepairService removed=\(result.removedCount, privacy: .public) skipped=\(result.skippedCount, privacy: .public)")
            didRunSessionPhantomRepair = true
        } catch {
            logger.error("SessionPhantomRepairService failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Asegura que todos los pacientes tengan un número de HC legible.
    /// Corre en cada launch para cubrir pacientes viejos o sincronizados
    /// desde otros dispositivos con datos incompletos.
    @MainActor
    private func runPatientRecordRepairIfNeeded() async {
        guard professionals.first != nil else {
            didResolvePatientRecordRepairForCurrentLaunch = true
            return
        }

        guard isRunningPatientRecordRepair == false else { return }

        didResolvePatientRecordRepairForCurrentLaunch = false
        isRunningPatientRecordRepair = true
        defer {
            isRunningPatientRecordRepair = false
            didResolvePatientRecordRepairForCurrentLaunch = true
        }

        do {
            _ = try PatientMedicalRecordNumberService()
                .repairMissingRecordNumbers(in: modelContext)
        } catch {
            logger.error("PatientMedicalRecordNumberService failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    // MARK: - Privacidad en app switcher

    /// Cubre la UI completa cuando iOS hace el screenshot para el app switcher.
    /// scenePhase pasa por .inactive antes de .background — ese es el momento
    /// en que el sistema captura la pantalla. Color.background es el color de
    /// fondo del sistema: respeta el modo claro/oscuro sin requerir UIKit.
    @ViewBuilder
    private var privacyOverlay: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
    }

    // MARK: - Banner de base de datos no disponible

    /// Se muestra cuando la base de datos persistente no pudo inicializarse
    /// y la app está corriendo sobre un contenedor en memoria temporario.
    @ViewBuilder
    private var databaseUnavailableBanner: some View {
        Label(
            "Los datos de esta sesión no se guardarán. Reiniciá la app para intentar recuperar el acceso.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.footnote.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(radius: 4)
    }
}

#Preview("Sin perfil — Onboarding") {
    ContentView()
        .modelContainer(ModelContainer.preview)
}

#Preview("Con perfil — Lista de Pacientes") {
    let container = ModelContainer.preview
    let professional = Professional(
        fullName: "Dra. María López",
        licenseNumber: "MN 54321",
        specialty: "Psicología",
        email: "maria@example.com"
    )
    let _ = container.mainContext.insert(professional)

    let patients = [
        Patient(firstName: "Ana", lastName: "García", professional: professional),
        Patient(firstName: "Carlos", lastName: "Rodríguez", professional: professional),
        Patient(firstName: "María", lastName: "López", email: "maria.l@example.com", professional: professional),
    ]
    let _ = patients.map { container.mainContext.insert($0) }

    ContentView()
        .modelContainer(container)
}
