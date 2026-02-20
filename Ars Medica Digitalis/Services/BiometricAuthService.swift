//
//  BiometricAuthService.swift
//  Ars Medica Digitalis
//
//  Servicio de autenticación biométrica para proteger el acceso
//  al contenido clínico sensible de la app.
//

import Foundation
import LocalAuthentication

struct BiometricCapability: Equatable {

    enum Kind: Equatable {
        case faceID
        case touchID
        case opticID
        case none
    }

    var kind: Kind
    var isAvailable: Bool
    var unavailableReason: String?

    var localizedName: String {
        switch kind {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .none: "Biometría"
        }
    }
}

enum BiometricAuthOutcome: Equatable {
    case success
    case cancelled
    case failed(String)
}

struct BiometricAuthService {

    // MARK: - Capacidad

    func capability() -> BiometricCapability {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        if canEvaluate {
            return BiometricCapability(
                kind: mapBiometryType(context.biometryType),
                isAvailable: true,
                unavailableReason: nil
            )
        }

        return BiometricCapability(
            kind: mapBiometryType(context.biometryType),
            isAvailable: false,
            unavailableReason: capabilityMessage(from: error)
        )
    }

    // MARK: - Autenticación

    func authenticateBiometrically(reason: String) async -> BiometricAuthOutcome {
        await evaluate(
            policy: .deviceOwnerAuthenticationWithBiometrics,
            reason: reason,
            forceBiometricOnly: true
        )
    }

    /// Fallback para casos de lockout o cambios de configuración biométrica.
    /// Permite desbloquear usando el código del dispositivo.
    func authenticateWithDeviceOwner(reason: String) async -> BiometricAuthOutcome {
        await evaluate(
            policy: .deviceOwnerAuthentication,
            reason: reason,
            forceBiometricOnly: false
        )
    }

    // MARK: - Internals

    private func evaluate(
        policy: LAPolicy,
        reason: String,
        forceBiometricOnly: Bool
    ) async -> BiometricAuthOutcome {
        let context = LAContext()
        if forceBiometricOnly {
            context.localizedFallbackTitle = ""
        }

        var policyError: NSError?
        guard context.canEvaluatePolicy(policy, error: &policyError) else {
            return .failed(capabilityMessage(from: policyError))
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: .success)
                    return
                }

                guard let laError = error as? LAError else {
                    continuation.resume(
                        returning: .failed(
                            error?.localizedDescription ?? "No se pudo autenticar tu identidad."
                        )
                    )
                    return
                }

                switch laError.code {
                case .userCancel, .systemCancel, .appCancel, .userFallback:
                    continuation.resume(returning: .cancelled)
                default:
                    continuation.resume(returning: .failed(authMessage(for: laError)))
                }
            }
        }
    }

    private func mapBiometryType(_ biometryType: LABiometryType) -> BiometricCapability.Kind {
        switch biometryType {
        case .faceID: .faceID
        case .touchID: .touchID
        case .opticID: .opticID
        case .none: .none
        @unknown default: .none
        }
    }

    private func capabilityMessage(from error: NSError?) -> String {
        guard let laError = error as? LAError else {
            return "La autenticación biométrica no está disponible."
        }

        switch laError.code {
        case .biometryNotAvailable:
            return "Este dispositivo no tiene autenticación biométrica disponible."
        case .biometryNotEnrolled:
            return "No hay datos biométricos configurados en el dispositivo."
        case .passcodeNotSet:
            return "Configurá un código de desbloqueo para habilitar biometría."
        case .biometryLockout:
            return "La biometría está bloqueada por múltiples intentos fallidos."
        default:
            return laError.localizedDescription
        }
    }

    private func authMessage(for error: LAError) -> String {
        switch error.code {
        case .authenticationFailed:
            return "No se pudo verificar tu identidad."
        case .biometryLockout:
            return "La biometría quedó bloqueada. Intentá con el código del dispositivo."
        case .biometryNotAvailable:
            return "La biometría no está disponible en este momento."
        case .biometryNotEnrolled:
            return "No hay datos biométricos configurados en el dispositivo."
        case .passcodeNotSet:
            return "Configurá un código de desbloqueo para usar biometría."
        default:
            return error.localizedDescription
        }
    }
}
