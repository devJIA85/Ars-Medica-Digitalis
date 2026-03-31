//
//  AvatarImageStore.swift
//  Ars Medica Digitalis
//
//  Gestión centralizada de archivos de avatar generados con Image Playground.
//
//  POLÍTICA DE ALMACENAMIENTO
//  ---------------------------
//  Las imágenes se guardan en Application Support/Avatars/ (no en Documents/).
//  Motivo: Application Support es respaldado por iCloud Backup (como Documents),
//  pero NO es visible en la app Archivos del usuario ni purgeable por el sistema.
//  Es el lugar correcto para assets generados por la app que el usuario no gestiona
//  directamente. Ver: "File System Basics" — Apple Developer Documentation.
//
//  POLÍTICA DE CLEANUP
//  --------------------
//  1. Al confirmar un nuevo avatar generado: se elimina el archivo anterior si existía.
//  2. Al cancelar una generación pendiente: se elimina el temporal no asignado.
//  3. removeOrphans(keeping:): elimina cualquier archivo en el directorio que no
//     corresponda al nombre activo. Llamar en arranque o tras eventos de limpieza.
//
//  Toda la lógica de file management está aquí. Ninguna otra capa del feature
//  toca FileManager directamente.
//

import UIKit
import OSLog

enum AvatarImageStore {

    private static let logger = Logger(
        subsystem: "com.arsmedica.digitalis",
        category: "AvatarImageStore"
    )

    // MARK: - Directorio

    /// Directorio permanente donde se almacenan los avatars generados.
    static var avatarsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Avatars", isDirectory: true)
    }

    // MARK: - Operaciones de escritura

    /// Persiste la imagen temporal de Image Playground en almacenamiento permanente
    /// con protección de archivo y escritura atómica.
    ///
    /// Image Playground devuelve una URL temporal cuyo ciclo de vida no está garantizado
    /// más allá del callback de completion. Esta función debe llamarse inmediatamente
    /// en el handler para garantizar la persistencia.
    ///
    /// PROTECCIÓN DE ARCHIVO
    /// ----------------------
    /// Se usa `Data.write(to:options:)` con `[.atomic, .completeFileProtectionUnlessOpen]`
    /// en lugar de `FileManager.copyItem`, porque:
    ///   • `copyItem` NO preserva ni aplica atributos de protección al archivo destino.
    ///     El archivo quedaría desprotegido entre la copia y un eventual `setResourceValue`.
    ///   • `Data.write` con estas opciones aplica la protección de forma atómica: escribe
    ///     a un archivo temporal y hace swap atómico, garantizando integridad en caso de
    ///     crash y protección activa desde el primer byte escrito en disco.
    ///
    /// `.completeFileProtectionUnlessOpen`:
    ///   • El archivo queda cifrado cuando el dispositivo está bloqueado y la app no lo tiene
    ///     abierto. Al reabrir la app (dispositivo desbloqueado), es accesible sin fricción.
    ///   • Nivel recomendado por Apple para assets personales no ultra-sensibles que el sistema
    ///     pueda necesitar acceder en background (ver "Encrypting Your App's Files").
    ///   • En Simulator: el filesystem APFS soporta protección; el comportamiento es equivalente.
    ///
    /// - Parameter tempURL: URL temporal recibida del completion handler de Image Playground.
    /// - Returns: Nombre de archivo asignado (UUID-based, único).
    /// - Throws: `Data(contentsOf:)` o `Data.write` si la lectura o escritura falla.
    @discardableResult
    static func save(from tempURL: URL) throws -> String {
        try ensureDirectory()
        let fileName = "avatar_\(UUID().uuidString).jpg"
        let destURL = avatarsDirectory.appendingPathComponent(fileName)
        let imageData = try Data(contentsOf: tempURL)
        try imageData.write(to: destURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        logger.info("Avatar image saved with file protection")
        return fileName
    }

    /// Elimina el archivo de avatar con el nombre indicado.
    /// Silencioso si el archivo no existe (idempotente).
    static func delete(fileName: String) {
        let url = avatarsDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: url)
            logger.info("Avatar image deleted")
        } catch CocoaError.fileNoSuchFile {
            // Ya fue eliminado — no es un error.
        } catch {
            logger.warning("Failed to delete avatar image: \(error, privacy: .private)")
        }
    }

    // MARK: - Operaciones de lectura

    /// URL permanente para un nombre de archivo dado.
    static func url(for fileName: String) -> URL {
        avatarsDirectory.appendingPathComponent(fileName)
    }

    /// Carga la UIImage desde disco. nil si el archivo no existe o es inválido.
    static func loadImage(named fileName: String) -> UIImage? {
        let path = url(for: fileName).path
        guard FileManager.default.fileExists(atPath: path) else {
            logger.warning("Avatar image file not found: missing from disk")
            return nil
        }
        return UIImage(contentsOfFile: path)
    }

    // MARK: - Cleanup defensivo

    /// Elimina todos los archivos `.jpg` del directorio Avatars que NO estén
    /// referenciados en el conjunto de nombres activos.
    ///
    /// Recibe un `Set<String>` en lugar de un único nombre para soportar correctamente
    /// el escenario donde existen —o existirán— múltiples Professional en la base de
    /// datos, cada uno potencialmente con su propio avatar generado. Usar un único
    /// nombre sería inseguro: borraría archivos válidos de otros Professional.
    ///
    /// Cuándo llamar:
    /// - Al pasar a primer plano (`scenePhase == .active`), como cleanup global.
    /// - Tras confirmar o cancelar una selección de avatar.
    ///
    /// - Parameter activeFileNames: Conjunto de nombres de archivo actualmente en uso.
    ///   Un conjunto vacío indica que ningún Professional tiene avatar generado;
    ///   en ese caso se eliminan todos los archivos del directorio.
    static func removeOrphans(keeping activeFileNames: Set<String>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: avatarsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in contents where fileURL.pathExtension.lowercased() == "jpg" {
            let name = fileURL.lastPathComponent
            guard !activeFileNames.contains(name) else { continue }
            do {
                try FileManager.default.removeItem(at: fileURL)
                logger.info("Removed orphan avatar image")
            } catch {
                logger.warning("Failed to remove orphan avatar: \(error, privacy: .private)")
            }
        }
    }

    // MARK: - Privado

    private static func ensureDirectory() throws {
        let dir = avatarsDirectory
        guard !FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}
