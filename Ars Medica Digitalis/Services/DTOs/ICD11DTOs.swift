//
//  ICD11DTOs.swift
//  Ars Medica Digitalis
//
//  Tipos de transferencia para la comunicación con la API del CIE-11.
//  Son structs puros — no persisten en SwiftData. Los datos relevantes
//  se copian al modelo Diagnosis como snapshot inmutable al guardar.
//

import Foundation

// MARK: - OAuth Token Response

/// Respuesta del endpoint de autenticación OAuth2 de la OMS.
struct ICD11TokenResponse: Sendable {
    let access_token: String
    let expires_in: Int
    let token_type: String
}

extension ICD11TokenResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.access_token = try container.decode(String.self, forKey: .access_token)
        self.expires_in = try container.decode(Int.self, forKey: .expires_in)
        self.token_type = try container.decode(String.self, forKey: .token_type)
    }
    
    private enum CodingKeys: String, CodingKey {
        case access_token
        case expires_in
        case token_type
    }
}

// MARK: - Search Result

/// Un resultado individual de búsqueda en la linearización MMS del CIE-11.
/// Solo incluye los campos que AMD necesita para la UI y el snapshot.
struct ICD11SearchResult: Identifiable, Sendable {
    /// URI canónico del WHO (ej: "http://id.who.int/icd/entity/123456")
    let id: String
    /// Código MMS (ej: "6A70"). Puede ser nil para categorías intermedias.
    let theCode: String?
    /// Título en el idioma solicitado, ya limpio de etiquetas HTML.
    let title: String
    /// Capítulo al que pertenece (ej: "06")
    let chapter: String?
    /// Puntuación de relevancia devuelta por la API
    let score: Double?
}
