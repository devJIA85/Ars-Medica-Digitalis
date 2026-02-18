//
//  Attachment.swift
//  Ars Medica Digitalis
//
//  Adjuntos a una sesión (estudios, imágenes, documentos escaneados).
//  El binario se almacena como CloudKit Asset, no dentro del registro,
//  para respetar el límite de 1MB por record.
//

import Foundation
import SwiftData

@Model
final class Attachment {

    var id: UUID = UUID()

    var fileName: String = ""
    var fileType: String = ""              // MIME type: "application/pdf", "image/jpeg"
    var fileSizeBytes: Int = 0

    // Referencia al CKAsset en CloudKit. Los binarios grandes
    // van como Assets para evitar el límite de 1MB por registro.
    var cloudKitAssetURL: String = ""

    // Path local temporal en el FileSystem del dispositivo (cache).
    // No se sincroniza directamente — se reconstruye desde el Asset.
    var localCachePath: String = ""

    var uploadStatus: String = "pendiente"  // "pendiente" | "subiendo" | "completado" | "error"

    var createdAt: Date = Date()

    // Relación opcional por requisito CloudKit
    var session: Session? = nil
    
    init(
        id: UUID = UUID(),
        fileName: String = "",
        fileType: String = "",
        fileSizeBytes: Int = 0,
        cloudKitAssetURL: String = "",
        localCachePath: String = "",
        uploadStatus: String = "pendiente",
        createdAt: Date = Date(),
        session: Session? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileType = fileType
        self.fileSizeBytes = fileSizeBytes
        self.cloudKitAssetURL = cloudKitAssetURL
        self.localCachePath = localCachePath
        self.uploadStatus = uploadStatus
        self.createdAt = createdAt
        self.session = session
    }
}
