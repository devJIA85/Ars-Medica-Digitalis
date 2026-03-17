//
//  ContentView.swift
//  Ars Medica Digitalis
//
//  Created by Juan Ignacio Antolini on 18/02/2026.
//

import SwiftUI
import SwiftData

/// Vista raíz que controla el flujo principal de la app:
/// - Sin Professional → Onboarding (HU-01)
/// - Con Professional → Lista de pacientes (HU-02, HU-03)
struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var professionals: [Professional]
    @AppStorage("security.biometricEnabled") private var biometricLockEnabled: Bool = false
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
        .onChange(of: biometricLockEnabled) { _, isEnabled in
            handleBiometricToggleChange(isEnabled: isEnabled)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onOpenURL { url in
            handleIncomingDeepLink(url)
        }
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

    @ViewBuilder
    private func mainView(for professional: Professional) -> some View {
        TabView {
            Tab("Pacientes", systemImage: "person.2") {
                NavigationStack {
                    PatientListView(
                        professional: professional,
                        namespace: patientTransition,
                        onAddPatient: { showingNewPatient = true },
                        enablesSearch: true
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

            Tab("Perfil", systemImage: "person.crop.circle") {
                NavigationStack {
                    ProfileView(professional: professional)
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
        biometricLockEnabled && professionals.first != nil
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
                biometricLockEnabled = false
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
            print("SessionPhantomRepairService removed=\(result.removedCount) skipped=\(result.skippedCount)")
            didRunSessionPhantomRepair = true
        } catch {
            print("SessionPhantomRepairService failed: \(error.localizedDescription)")
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
            print("PatientMedicalRecordNumberService failed: \(error.localizedDescription)")
        }
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
