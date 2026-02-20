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
    @State private var isAuthenticating: Bool = false
    @State private var lockErrorMessage: String? = nil
    @State private var biometricCapability = BiometricCapability(
        kind: .none,
        isAvailable: false,
        unavailableReason: nil
    )

    private let biometricAuthService = BiometricAuthService()

    private enum LaunchPhase {
        case splash
        case ready
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
        .onChange(of: professionals.first?.id) { _, _ in
            handleProtectionContextChange()
        }
        .onChange(of: biometricLockEnabled) { _, isEnabled in
            handleBiometricToggleChange(isEnabled: isEnabled)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    // MARK: - Vista principal

    @ViewBuilder
    private var rootContent: some View {
        if let professional = professionals.first {
            if shouldRequireLock && !isAppUnlocked {
                AppLockView(
                    capability: biometricCapability,
                    isAuthenticating: isAuthenticating,
                    errorMessage: lockErrorMessage,
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

    @ViewBuilder
    private func mainView(for professional: Professional) -> some View {
        TabView {
            Tab("Pacientes", systemImage: "person.2") {
                NavigationStack {
                    PatientListView(
                        professional: professional,
                        namespace: patientTransition,
                        onAddPatient: { showingNewPatient = true }
                    )
                        .navigationDestination(for: UUID.self) { patientID in
                            PatientDestinationView(
                                patientID: patientID,
                                professional: professional
                            )
                            // Transición zoom: la fila de la lista se expande
                            // hacia la vista de detalle del paciente.
                            .navigationTransition(.zoom(sourceID: patientID, in: patientTransition))
                        }
                }
            }

            Tab("Calendario", systemImage: "calendar") {
                NavigationStack {
                    CalendarView(professional: professional)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $showingNewPatient) {
            NavigationStack {
                PatientFormView(professional: professional)
            }
        }
        .task {
            // Poblar catálogo CIE-11 offline en background (solo primer launch)
            let service = ICD11SeedService(modelContainer: modelContext.container)
            await service.seedIfNeeded()
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
    private func handleProtectionContextChange() {
        biometricCapability = biometricAuthService.capability()

        if shouldRequireLock {
            isAppUnlocked = false
        } else {
            isAppUnlocked = true
            lockErrorMessage = nil
        }
    }

    @MainActor
    private func handleBiometricToggleChange(isEnabled: Bool) {
        if isEnabled {
            biometricCapability = biometricAuthService.capability()
            guard biometricCapability.isAvailable else {
                biometricLockEnabled = false
                return
            }

            if professionals.first != nil {
                isAppUnlocked = false
                Task { await unlockWithBiometrics() }
            }
        } else {
            isAppUnlocked = true
            lockErrorMessage = nil
        }
    }

    @MainActor
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard shouldRequireLock else { return }

        switch phase {
        case .background, .inactive:
            isAppUnlocked = false
        case .active:
            Task { await unlockWithBiometrics() }
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
        guard !isAuthenticating else { return }

        isAuthenticating = true
        lockErrorMessage = nil
        biometricCapability = biometricAuthService.capability()

        let result = await biometricAuthService.authenticateBiometrically(
            reason: "Desbloqueá Ars Medica Digitalis para acceder a historias clínicas."
        )

        isAuthenticating = false

        switch result {
        case .success:
            isAppUnlocked = true
            lockErrorMessage = nil
        case .cancelled:
            isAppUnlocked = false
        case .failed(let message):
            isAppUnlocked = false
            lockErrorMessage = message
        }
    }

    @MainActor
    private func unlockWithDeviceOwnerAuthentication() async {
        guard shouldRequireLock else {
            isAppUnlocked = true
            return
        }
        guard !isAuthenticating else { return }

        isAuthenticating = true
        lockErrorMessage = nil

        let result = await biometricAuthService.authenticateWithDeviceOwner(
            reason: "Validá tu identidad para acceder a Ars Medica Digitalis."
        )

        isAuthenticating = false

        switch result {
        case .success:
            isAppUnlocked = true
            lockErrorMessage = nil
        case .cancelled:
            isAppUnlocked = false
        case .failed(let message):
            isAppUnlocked = false
            lockErrorMessage = message
        }
    }
}

/// Vista auxiliar que resuelve el Patient desde su UUID.
/// Necesaria porque navigationDestination(for:) recibe un valor,
/// no un objeto SwiftData directamente.
private struct PatientDestinationView: View {

    @Query private var patients: [Patient]

    let patientID: UUID
    let professional: Professional

    /// Trigger para haptic al llegar a la vista de detalle.
    /// Se activa una sola vez en onAppear.
    @State private var didAppear: Bool = false

    init(patientID: UUID, professional: Professional) {
        self.patientID = patientID
        self.professional = professional

        let id = patientID
        _patients = Query(
            filter: #Predicate<Patient> { $0.id == id }
        )
    }

    var body: some View {
        if let patient = patients.first {
            PatientDetailView(patient: patient, professional: professional)
                // Haptic sutil al navegar — feedback de "aterrizaje" en el detalle
                .onAppear { didAppear = true }
                .sensoryFeedback(.impact(flexibility: .soft), trigger: didAppear)
        } else {
            ContentUnavailableView(
                "Paciente no encontrado",
                systemImage: "exclamationmark.triangle"
            )
        }
    }
}

#Preview("Sin perfil — Onboarding") {
    ContentView()
        .modelContainer(for: [
            Professional.self,
            Patient.self,
            Session.self,
            Diagnosis.self,
            Attachment.self,
            PriorTreatment.self,
            Hospitalization.self,
            AnthropometricRecord.self,
            ICD11Entry.self,
        ], inMemory: true)
}

#Preview("Con perfil — Lista de Pacientes") {
    let container = try! ModelContainer(
        for: Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self, PriorTreatment.self, Hospitalization.self, AnthropometricRecord.self, ICD11Entry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
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

