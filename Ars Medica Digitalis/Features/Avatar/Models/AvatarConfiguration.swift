//
//  AvatarConfiguration.swift
//  Ars Medica Digitalis
//
//  Tipos de datos del sistema de avatar del profesional.
//
//  DISEÑO DE PERSISTENCIA
//  -----------------------
//  La configuración completa se serializa como JSON en un único campo `Data?`
//  (`Professional.avatarConfigData`). Esto reemplaza el esquema anterior de tres
//  campos raw/string independientes y aporta:
//    • Type safety: no hay strings mágicos ni decodificación distribuida.
//    • Evolución sin dolor: agregar campos al Codable no rompe datos existentes.
//    • DRY: la lógica de encode/decode queda en un solo lugar.
//    • El tipo `Data?` es un primitivo nativo de CKRecord (mejor base que strings dispersos).
//
//  NOTA SOBRE CLOUDKIT
//  --------------------
//  Usar un único campo `Data?` reduce complejidad y mejora la encapsulación frente al
//  esquema anterior. Sin embargo, esto NO equivale a garantizar compatibilidad total
//  con CloudKit. Antes de reactivar la sincronización habrá que validar:
//    • Inicialización y promoción del schema en CloudKit Dashboard (desarrollo → producción).
//    • Comportamiento de sync: conflictos, merge, orden de escritura.
//    • Evolución de datos: CloudKit no permite eliminar campos ya promovidos a producción.
//    • Compatibilidad entre versiones de la app: clientes con versiones distintas del
//      JSON pueden decodificar distintas versiones del Codable.
//    • Capacidades en el target: iCloud + CloudKit + Background Modes (remote notifications).
//
//  NOTA DE MIGRACIÓN
//  -----------------
//  Los tres campos antiguos (avatarTypeRaw / avatarValueRaw / avatarPromptMetadataJSON)
//  se eliminaron. Si existía una base de datos local con esos campos, se requiere
//  "Clean Build + borrar app del simulador/dispositivo" en el entorno de desarrollo.
//  Para producción, se necesitaría una etapa de migración ligera.
//

import Foundation
import SwiftUI
import OSLog

// MARK: - PredefinedAvatarStyle

/// Estilo de avatar del catálogo predefinido.
/// Cada caso combina un SF Symbol y un color de presentación.
/// `rawValue` es el string persistido dentro del JSON de `AvatarConfiguration`.
enum PredefinedAvatarStyle: String, CaseIterable, Codable, Identifiable {

    case blue        = "avatar_blue"
    case teal        = "avatar_teal"
    case indigo      = "avatar_indigo"
    case purple      = "avatar_purple"
    case pink        = "avatar_pink"
    case orange      = "avatar_orange"
    case stethoscope = "avatar_stethoscope"
    case cross       = "avatar_cross"
    case heart       = "avatar_heart"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .stethoscope: return "stethoscope.circle.fill"
        case .cross:       return "cross.circle.fill"
        case .heart:       return "heart.circle.fill"
        default:           return "person.crop.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .blue:        return .blue
        case .teal:        return .teal
        case .indigo:      return .indigo
        case .purple:      return .purple
        case .pink:        return .pink
        case .orange:      return .orange
        case .stethoscope: return .cyan
        case .cross:       return .green
        case .heart:       return .red
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .blue:        return "Azul"
        case .teal:        return "Verde azulado"
        case .indigo:      return "Índigo"
        case .purple:      return "Violeta"
        case .pink:        return "Rosa"
        case .orange:      return "Naranja"
        case .stethoscope: return "Estetoscopio"
        case .cross:       return "Cruz médica"
        case .heart:       return "Corazón"
        }
    }
}

// MARK: - AvatarGenerationMetadata

/// Metadatos de una imagen generada con Image Playground.
/// Se persiste junto al nombre de archivo para reproducibilidad y trazabilidad.
struct AvatarGenerationMetadata: Codable, Hashable {

    /// Texto libre ingresado por el usuario como descripción de vibra/estilo.
    let vibe: String

    /// Prompt completo efectivamente enviado a Image Playground.
    /// Incluye el texto del usuario más los conceptos de contexto clínico agregados
    /// por la app. Permite reproducir la generación con los mismos parámetros.
    let fullPrompt: String

    /// Fecha de generación. Útil para auditoría local y orden en futuras listas.
    let generatedAt: Date
}

// MARK: - AvatarConfiguration

/// Configuración del avatar del profesional.
///
/// Dos casos mutuamente excluyentes:
/// - `predefined`: estilo del catálogo incorporado (SF Symbol + color, sin assets externos)
/// - `generated`: imagen producida por Image Playground, almacenada en Application Support/Avatars/
///
/// Conforma `Codable` con implementación manual para garantizar estabilidad del formato
/// JSON ante futuros cambios en los casos o sus valores asociados.
enum AvatarConfiguration: Hashable {
    case predefined(style: PredefinedAvatarStyle)
    case generated(imageFileName: String, metadata: AvatarGenerationMetadata)
}

// MARK: - Codable

extension AvatarConfiguration: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind, style, imageFileName, metadata
    }

    private enum Kind: String, Codable {
        case predefined, generated
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .predefined(let style):
            try c.encode(Kind.predefined, forKey: .kind)
            try c.encode(style, forKey: .style)
        case .generated(let fileName, let metadata):
            try c.encode(Kind.generated, forKey: .kind)
            try c.encode(fileName, forKey: .imageFileName)
            try c.encode(metadata, forKey: .metadata)
        }
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .predefined:
            let style = try c.decode(PredefinedAvatarStyle.self, forKey: .style)
            self = .predefined(style: style)
        case .generated:
            let fileName = try c.decode(String.self, forKey: .imageFileName)
            let metadata = try c.decode(AvatarGenerationMetadata.self, forKey: .metadata)
            self = .generated(imageFileName: fileName, metadata: metadata)
        }
    }
}

// MARK: - Persistencia (Data <-> AvatarConfiguration)

extension AvatarConfiguration {

    /// Logger para decode failures. Struct Sendable — seguro como static let en extensiones.
    private static let logger = Logger(
        subsystem: "com.arsmedica.digitalis",
        category: "AvatarConfiguration"
    )

    static let defaultValue: AvatarConfiguration = .predefined(style: .blue)

    /// Decodifica desde el campo `Professional.avatarConfigData`.
    ///
    /// Comportamiento ante fallos:
    /// - `data == nil`: primer uso o Professional sin avatar guardado → `.defaultValue` silencioso.
    /// - `data != nil` pero decode falla: corrupción, incompatibilidad de versión o migración
    ///   no contemplada → loguea el error con `.error` y devuelve `.defaultValue`.
    ///   El fallback preserva la UX; el log permite detectar el problema en desarrollo.
    static func from(data: Data?) -> AvatarConfiguration {
        guard let data else { return defaultValue }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(AvatarConfiguration.self, from: data)
        } catch {
            logger.error(
                "AvatarConfiguration decode failed — usando defaultValue como recuperación defensiva: \(error, privacy: .private)"
            )
            return defaultValue
        }
    }

    /// Serializa para guardar en `Professional.avatarConfigData`.
    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
}
