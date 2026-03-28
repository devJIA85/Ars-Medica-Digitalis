//
//  BiometricLockCoordinator.swift
//  Ars Medica Digitalis
//
//  Encapsula el estado y la lógica de autenticación biométrica.
//  Extraído de ContentView para reducir la carga de @State y
//  hacer el flujo de desbloqueo testeable en aislamiento.
//

import Foundation

/// Gestiona el estado de autenticación biométrica de la app.
/// ContentView conserva `isAppUnlocked` porque depende de lógica
/// de negocio (biometricLockEnabled + existencia de Professional).
@Observable
@MainActor
final class BiometricLockCoordinator {

    // MARK: - Estado observable

    private(set) var isAuthenticating: Bool = false
    private(set) var errorMessage: String?
    private(set) var capability: BiometricCapability

    // MARK: - Dependencia

    private let service = BiometricAuthService()

    // MARK: - Init

    init() {
        capability = service.capability()
    }

    // MARK: - API pública

    /// Refresca la capacidad biométrica del dispositivo.
    /// Llamar cuando el usuario cambia la configuración o al volver al primer plano.
    func refreshCapability() {
        capability = service.capability()
    }

    /// Limpia el mensaje de error (p.ej. al desactivar el bloqueo).
    func clearError() {
        errorMessage = nil
    }

    /// Autentica con biometría (Face ID / Touch ID / Optic ID).
    /// - Returns: `true` si la autenticación tuvo éxito.
    @discardableResult
    func authenticateBiometrically() async -> Bool {
        await performAuthentication {
            await self.service.authenticateBiometrically(
                reason: L10n.tr("biometric.reason")
            )
        }
    }

    /// Autentica con el código del dispositivo (fallback de biometría bloqueada).
    /// - Returns: `true` si la autenticación tuvo éxito.
    @discardableResult
    func authenticateWithPasscode() async -> Bool {
        await performAuthentication {
            await self.service.authenticateWithDeviceOwner(
                reason: "Validá tu identidad para acceder a Ars Medica Digitalis."
            )
        }
    }

    // MARK: - Internals

    private func performAuthentication(
        _ method: () async -> BiometricAuthOutcome
    ) async -> Bool {
        guard !isAuthenticating else { return false }

        isAuthenticating = true
        errorMessage = nil
        // No refrescar capability aquí: evaluate() crea su propio LAContext y llama
        // canEvaluatePolicy internamente con ese mismo contexto antes de evaluatePolicy.
        // Crear un LAContext adicional en esta capa sería redundante y generaría una
        // evaluación extra que no se usa para la autenticación real.
        // refreshCapability() se llama desde ContentView cuando cambia scenePhase o
        // cuando el usuario activa/desactiva el bloqueo biométrico.

        let result = await method()
        isAuthenticating = false

        switch result {
        case .success:
            errorMessage = nil
            return true
        case .cancelled:
            return false
        case .failed(let message):
            errorMessage = message
            return false
        }
    }
}
