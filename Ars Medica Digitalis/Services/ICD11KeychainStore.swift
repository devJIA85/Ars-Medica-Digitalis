//
//  ICD11KeychainStore.swift
//  Ars Medica Digitalis
//
//  Persiste las credenciales OAuth2 del CIE-11 en el Keychain del dispositivo,
//  fuera del bundle de la app y sin sincronización con iCloud.
//
//  Flujo de primer uso:
//  1. Se intentan leer desde el Keychain.
//  2. Si no existen, se leen desde ICD11Config.plist (en bundle) y se migran
//     al Keychain. En producción el plist debería ser eliminado del bundle
//     una vez migradas las credenciales.
//

import Foundation
import Security
import OSLog

enum ICD11KeychainStore {

    private static let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "ICD11Keychain")

    private enum Key {
        static let clientId     = "icd11.clientId"
        static let clientSecret = "icd11.clientSecret"
    }

    // MARK: - API pública

    /// Devuelve las credenciales desde el Keychain.
    /// En el primer lanzamiento migra automáticamente desde `ICD11Config.plist`.
    static func loadCredentials() throws -> (clientId: String, clientSecret: String) {
        if let stored = readFromKeychain() {
            return stored
        }

        // Primera vez: migrar desde plist
        let plist = try loadFromPlist()
        try writeToKeychain(clientId: plist.clientId, clientSecret: plist.clientSecret)
        logger.info("ICD11 credentials migrated to Keychain.")
        return plist
    }

    // MARK: - Keychain (lectura / escritura)

    private static func readFromKeychain() -> (clientId: String, clientSecret: String)? {
        guard let clientId = readItem(key: Key.clientId),
              let clientSecret = readItem(key: Key.clientSecret) else {
            return nil
        }
        return (clientId, clientSecret)
    }

    private static func readItem(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:                   kSecClassGenericPassword,
            kSecAttrAccount:             key,
            kSecReturnData:              true,
            kSecMatchLimit:              kSecMatchLimitOne,
            // Activa Data Protection Keychain en iOS modernos,
            // alineado con el nivel de protección del archivo SwiftData.
            kSecUseDataProtectionKeychain: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func writeToKeychain(clientId: String, clientSecret: String) throws {
        try writeItem(key: Key.clientId, value: clientId)
        try writeItem(key: Key.clientSecret, value: clientSecret)
    }

    private static func writeItem(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw ICD11KeychainError.encodingFailed
        }

        // Eliminar entrada previa si existe (upsert manual)
        let deleteQuery: [CFString: Any] = [
            kSecClass:                   kSecClassGenericPassword,
            kSecAttrAccount:             key,
            kSecUseDataProtectionKeychain: true
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass:                   kSecClassGenericPassword,
            kSecAttrAccount:             key,
            kSecValueData:               data,
            // AfterFirstUnlock: disponible en background tras el primer desbloqueo
            // del dispositivo. Apropiado para credentials de API externa que pueden
            // necesitarse en background fetch. ThisDeviceOnly: sin iCloud Keychain.
            kSecAttrAccessible:          kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecUseDataProtectionKeychain: true
            // kSecAttrAccessGroup: "TEAMID.com.arsmedica.shared"  ← descomentar si se agrega extension/widget
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain write failed for key \(key, privacy: .public): \(status)")
            throw ICD11KeychainError.writeFailed(status: status)
        }
    }

    // MARK: - Fallback plist

    private static func loadFromPlist() throws -> (clientId: String, clientSecret: String) {
        guard let url = Bundle.main.url(forResource: "ICD11Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String],
              let clientId = dict["clientId"],
              let clientSecret = dict["clientSecret"] else {
            throw ICD11Error.missingConfiguration(
                "ICD11Config.plist no encontrado o incompleto. "
                + "Debe contener 'clientId' y 'clientSecret' para la migración inicial al Keychain."
            )
        }
        return (clientId, clientSecret)
    }
}

// MARK: - Errores del Keychain

enum ICD11KeychainError: LocalizedError {
    case encodingFailed
    case writeFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "No se pudo codificar la credencial para el Keychain."
        case .writeFailed(let status):
            "Error al escribir en el Keychain (OSStatus \(status))."
        }
    }
}
