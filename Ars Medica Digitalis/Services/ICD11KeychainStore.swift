//
//  ICD11KeychainStore.swift
//  Ars Medica Digitalis
//
//  Persiste las credenciales OAuth2 del CIE-11 en el Keychain del dispositivo,
//  fuera del bundle de la app y sin sincronización con iCloud.
//
//  Flujo de loadCredentials():
//  1. Leer con esquema actual (kSecAttrService = Key.service). Caso habitual.
//  2. Si no existe → intentar migración de esquema legacy (sin kSecAttrService).
//     Cubre el primer launch tras actualizar desde una versión anterior de la app
//     que guardaba ítems sin service. Los ítems legacy se reescriben con el
//     esquema actual y se eliminan por referencia persistente.
//  3. Si tampoco hay legacy → migrar desde ICD11Config.plist al Keychain.
//     En producción el plist debería eliminarse del bundle tras esta migración.
//

import Foundation
import Security
import OSLog

nonisolated enum ICD11KeychainStore {

    private static let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "ICD11Keychain")

    private enum Key {
        static let clientId     = "icd11.clientId"
        static let clientSecret = "icd11.clientSecret"
        /// Service que identifica todos los ítems de este store en el Keychain.
        /// Junto con kSecAttrAccount forma la primary key del ítem. Distinto del
        /// service de SecurityPreferenceStore para evitar cualquier colisión futura.
        static let service      = "com.arsmedica.digitalis.icd11"
    }

    // MARK: - API pública

    /// Devuelve las credenciales desde el Keychain.
    /// En el primer lanzamiento migra automáticamente desde `ICD11Config.plist`.
    ///
    /// - En Release: requiere Keychain. Si la migración falla, lanza el error
    ///   para evitar exponer credenciales del bundle en producción.
    /// - En Debug/Simulator: permite fallback al plist para facilitar el desarrollo.
    static func loadCredentials() throws -> (clientId: String, clientSecret: String) {
        // Paso 1: esquema actual
        if let stored = readFromKeychain() {
            return stored
        }

        // Paso 2: migración de esquema legacy (pre-PR2, sin kSecAttrService).
        // Lee los ítems legacy, los reescribe con el esquema actual y los elimina.
        if let migrated = migrateFromLegacyKeychainIfNeeded() {
            return migrated
        }

        // Paso 3: primer uso — migrar desde plist al Keychain con esquema actual.
        let plist = try loadFromPlist()
        do {
            try writeToKeychain(clientId: plist.clientId, clientSecret: plist.clientSecret)
            logger.info("ICD11 credentials migrated to Keychain.")
        } catch {
#if DEBUG
            // En simulador/debug el Keychain puede no estar disponible.
            // Se acepta el fallback solo en entornos de desarrollo.
            logger.warning("Keychain migration failed (DEBUG only fallback): \(error, privacy: .private)")
            return plist
#else
            // En producción, no continuar con credenciales del bundle en texto plano.
            logger.error("Keychain migration failed in Release build: \(error, privacy: .public)")
            throw error
#endif
        }
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
            kSecClass:                     kSecClassGenericPassword,
            kSecAttrAccount:               key,
            kSecAttrService:               Key.service,
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

        // Patrón recomendado por Apple (Updating and Deleting Keychain Items):
        // SecItemAdd primero; SecItemUpdate si el ítem ya existe.
        let addQuery: [CFString: Any] = [
            kSecClass:                     kSecClassGenericPassword,
            kSecAttrAccount:               key,
            kSecAttrService:               Key.service,
            kSecValueData:                 data,
            // AfterFirstUnlock: disponible en background tras el primer desbloqueo
            // del dispositivo. Apropiado para credentials de API externa que pueden
            // necesitarse en background fetch. ThisDeviceOnly: sin iCloud Keychain.
            kSecAttrAccessible:            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecUseDataProtectionKeychain: true
            // kSecAttrAccessGroup: "TEAMID.com.arsmedica.shared"  ← descomentar si se agrega extension/widget
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        switch addStatus {
        case errSecSuccess:
            break
        case errSecDuplicateItem:
            // searchQuery usa exactamente los mismos atributos de identificación
            // que el addQuery: (kSecClass + kSecAttrAccount + kSecAttrService).
            // Esto garantiza que SecItemUpdate apunta al mismo ítem lógico que
            // habría creado SecItemAdd, sin riesgo de matchear otro ítem.
            let searchQuery: [CFString: Any] = [
                kSecClass:                     kSecClassGenericPassword,
                kSecAttrAccount:               key,
                kSecAttrService:               Key.service,
                kSecUseDataProtectionKeychain: true
            ]
            let updateAttributes: [CFString: Any] = [kSecValueData: data]
            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                // .private: el nombre de la clave es información interna del esquema
                logger.error("Keychain update failed for key \(key, privacy: .private): \(updateStatus)")
                throw ICD11KeychainError.writeFailed(status: updateStatus)
            }
        default:
            logger.error("Keychain write failed for key \(key, privacy: .private): \(addStatus)")
            throw ICD11KeychainError.writeFailed(status: addStatus)
        }
    }

    // MARK: - Migración de esquema Keychain legacy

    /// Intenta leer credenciales del esquema legacy (sin kSecAttrService),
    /// reescribirlas en el esquema actual y eliminar los ítems originales.
    ///
    /// Este paso es necesario para usuarios que actualizan desde una versión
    /// anterior de la app donde los ítems se guardaban sin `kSecAttrService`.
    /// Sin esta migración, `readFromKeychain()` no los encontraría (usa service)
    /// y la app caería al fallback del plist, que podría no existir en producción.
    ///
    /// Retorna `nil` si no existen ítems legacy — en ese caso el caller continúa
    /// con el fallback del plist.
    private static func migrateFromLegacyKeychainIfNeeded() -> (clientId: String, clientSecret: String)? {
        // Capturar referencias persistentes ANTES de escribir el nuevo esquema,
        // para poder eliminar exactamente estos ítems después sin riesgo de
        // matchear el ítem recién creado (una query sin service matchea cualquier
        // service, incluido el nuevo).
        guard let (clientId, clientIdRef) = readLegacyItemWithRef(key: Key.clientId),
              let (clientSecret, clientSecretRef) = readLegacyItemWithRef(key: Key.clientSecret) else {
            return nil
        }

        logger.info("ICD11 legacy Keychain items found — migrating to current schema.")

        do {
            try writeToKeychain(clientId: clientId, clientSecret: clientSecret)
            // Eliminar ítems legacy por referencia persistente. Esta es la única
            // forma segura de apuntar al ítem específico sin tocar el recién creado.
            deleteLegacyItem(persistentRef: clientIdRef, key: Key.clientId)
            deleteLegacyItem(persistentRef: clientSecretRef, key: Key.clientSecret)
            logger.info("ICD11 legacy Keychain migration complete.")
        } catch {
            // La escritura al nuevo esquema falló. Retornamos igualmente los valores
            // leídos del legacy para que la app funcione. El próximo launch reintentará
            // la migración (el legacy aún existe).
            logger.warning("ICD11 legacy migration write failed — will retry on next launch: \(error, privacy: .private)")
        }

        return (clientId, clientSecret)
    }

    /// Lee un ítem Keychain del esquema legacy (sin kSecAttrService) y devuelve
    /// el valor junto a su referencia persistente. La referencia permite eliminar
    /// exactamente este ítem más tarde, sin ambigüedad por la ausencia de service.
    private static func readLegacyItemWithRef(key: String) -> (value: String, ref: Data)? {
        let query: [CFString: Any] = [
            kSecClass:                     kSecClassGenericPassword,
            kSecAttrAccount:               key,
            // Sin kSecAttrService: identifica ítems del esquema pre-PR2.
            // No usar para escrituras ni para lecturas regulares.
            //
            // kSecAttrSynchronizable: false — restringe la búsqueda a ítems
            // no sincronizados (ThisDeviceOnly). Reduce la superficie de match:
            // excluye ítems de iCloud Keychain de otras apps que casualmente
            // compartan el mismo kSecAttrAccount.
            kSecAttrSynchronizable:        kCFBooleanFalse,
            kSecReturnData:                true,
            kSecReturnPersistentRef:       true,
            kSecMatchLimit:                kSecMatchLimitOne,
            kSecUseDataProtectionKeychain: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let dict = result as? [CFString: Any],
              let data = dict[kSecValueData] as? Data,
              let value = String(data: data, encoding: .utf8),
              let ref = dict[kSecValuePersistentRef] as? Data else {
            return nil
        }

        // Validar que el valor tiene formato esperado para una credencial OAuth2:
        // string no vacío después de trim, con longitud mínima razonable.
        // Rechazar datos claramente corruptos o ajenos antes de migrarlos.
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 8 else {
            logger.warning("Legacy Keychain item for key \(key, privacy: .private) failed validation — skipping migration.")
            return nil
        }

        return (trimmed, ref)
    }

    /// Elimina un ítem Keychain por referencia persistente (best-effort).
    /// Usar `kSecMatchItemList` garantiza que solo se elimina el ítem exacto
    /// obtenido en `readLegacyItemWithRef`, independientemente de sus atributos.
    private static func deleteLegacyItem(persistentRef: Data, key: String) {
        let deleteQuery: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecMatchItemList:   [persistentRef] as CFArray
        ]
        let status = SecItemDelete(deleteQuery as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.warning("Could not delete legacy Keychain item for key \(key, privacy: .private): \(status)")
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
