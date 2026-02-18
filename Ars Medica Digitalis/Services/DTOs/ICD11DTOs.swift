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
struct ICD11TokenResponse: Decodable, Sendable {
    let access_token: String
    let expires_in: Int
    let token_type: String
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
