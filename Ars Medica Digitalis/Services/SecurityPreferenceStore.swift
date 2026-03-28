//
//  SecurityPreferenceStore.swift
//  Ars Medica Digitalis
//
//  Persiste preferencias de seguridad en el Keychain del dispositivo.
//  Reemplaza @AppStorage para evitar exponer el estado de bloqueo biométrico
//  en UserDefaults, que es legible por cualquier proceso sin restricción.
//

import Foundation
import Security
import OSLog

/// Fuente de verdad para preferencias de seguridad persistidas en Keychain.
///
/// Se inyecta como @Environment a través de `EnvironmentValues.securityPreferences`
/// para que ContentView y ProfileSettingsView compartan el mismo estado.
/// No requiere @MainActor: las lecturas/escrituras de Keychain son thread-safe
/// y el acceso a la propiedad observable es siempre desde el Main thread en SwiftUI.
@Observable
final class SecurityPreferenceStore {

    private static let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "SecurityPreferences")

    private enum Key {
        static let biometricEnabled = "security.biometricEnabled"
    }

    // MARK: - Estado observable

    /// Refleja si el bloqueo biométrico está habilitado.
    /// Escribir este valor persiste el cambio en Keychain de forma automática.
    var biometricEnabled: Bool {
        didSet {
            guard oldValue != biometricEnabled else { return }
            do {
                try Self.writeToKeychain(biometricEnabled, forKey: Key.biometricEnabled)
            } catch {
                Self.logger.error("No se pudo persistir biometricEnabled en Keychain: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Init

    init() {
        // En UI tests usamos almacenamiento in-memory y nunca necesitamos biometría.
        // Usar un lanzamiento limpio sin modificar Keychain ni UserDefaults.
        let launchArgs = ProcessInfo.processInfo.arguments
        let isUITest = launchArgs.contains("UITEST_ONBOARDING")
            || launchArgs.contains("UITEST_PROFILE_DASHBOARD")
            || launchArgs.contains("UITEST_SCALES")

        if isUITest {
            biometricEnabled = false
        } else {
            biometricEnabled = Self.readFromKeychain(Key.biometricEnabled) ?? false
        }
    }

    // MARK: - Keychain

    private static func readFromKeychain(_ key: String) -> Bool? {
        let query: [CFString: Any] = [
            kSecClass:                     kSecClassGenericPassword,
            kSecAttrAccount:               key,
            kSecAttrService:               "com.arsmedica.digitalis.security",
            kSecReturnData:                true,
            kSecMatchLimit:                kSecMatchLimitOne,
            kSecUseDataProtectionKeychain: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value == "1"
    }

    private static func writeToKeychain(_ value: Bool, forKey key: String) throws {
        guard let data = (value ? "1" : "0").data(using: .utf8) else { return }

        // Patrón recomendado por Apple (Updating and Deleting Keychain Items):
        // intentar SecItemAdd primero; si el ítem ya existe (errSecDuplicateItem)
        // usar SecItemUpdate. Evita la ventana de fallo de delete+add donde
        // un SecItemAdd fallido después de un SecItemDelete exitoso deja el
        // Keychain sin el ítem y la siguiente lectura devuelve nil silenciosamente.
        let addQuery: [CFString: Any] = [
            kSecClass:                     kSecClassGenericPassword,
            kSecAttrAccount:               key,
            kSecAttrService:               "com.arsmedica.digitalis.security",
            kSecValueData:                 data,
            // WhenUnlocked: solo accesible cuando el dispositivo está desbloqueado.
            // Apropiado para preferencias de seguridad del usuario.
            kSecAttrAccessible:            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecUseDataProtectionKeychain: true
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        switch addStatus {
        case errSecSuccess:
            break
        case errSecDuplicateItem:
            // Ítem ya existe — actualizar solo el dato. SecItemUpdate preserva
            // kSecAttrAccessible y los atributos de control de acceso originales.
            let searchQuery: [CFString: Any] = [
                kSecClass:                     kSecClassGenericPassword,
                kSecAttrAccount:               key,
                kSecAttrService:               "com.arsmedica.digitalis.security",
                kSecUseDataProtectionKeychain: true
            ]
            let updateAttributes: [CFString: Any] = [kSecValueData: data]
            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw SecurityPreferenceError.writeFailed(status: updateStatus)
            }
        default:
            throw SecurityPreferenceError.writeFailed(status: addStatus)
        }
    }
}

// MARK: - Environment

import SwiftUI

private struct SecurityPreferenceStoreKey: EnvironmentKey {
    // nonisolated(unsafe): el valor por defecto se crea una sola vez al arrancar
    // la app y siempre se sobreescribe con el store real inyectado desde App.
    nonisolated(unsafe) static let defaultValue = SecurityPreferenceStore()
}

extension EnvironmentValues {
    var securityPreferences: SecurityPreferenceStore {
        get { self[SecurityPreferenceStoreKey.self] }
        set { self[SecurityPreferenceStoreKey.self] = newValue }
    }
}

// MARK: - Errores

enum SecurityPreferenceError: LocalizedError {
    case writeFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let status):
            "Error al escribir en el Keychain (OSStatus \(status))."
        }
    }
}
