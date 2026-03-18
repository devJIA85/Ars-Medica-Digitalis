//
//  PhoneContact.swift
//  Ars Medica Digitalis
//
//  Utilidades para acciones de contacto telefónico rápido:
//  normalización E.164, indicativos por país ISO, detección de WhatsApp
//  y construcción de URLs de acción.
//

import UIKit

enum PhoneContact {

    // MARK: - Normalización

    /// Normaliza un número telefónico al formato requerido por wa.me (solo dígitos, sin +).
    ///
    /// Detecta automáticamente tres variantes de entrada:
    /// - Formato internacional con `+`  → "+34 655 123 456"  → "34655123456"
    /// - Formato internacional con `00` → "0034655123456"    → "34655123456"
    /// - Número local sin prefijo       → "655 123 456"      → "34655123456" (requiere isoCountryCode)
    ///
    /// Si el número local no tiene `isoCountryCode`, se retorna tal cual (sin indicativo).
    /// Retorna nil si el resultado final tiene menos de 7 dígitos.
    ///
    /// - Parameters:
    ///   - raw: Número telefónico almacenado, en cualquier formato.
    ///   - isoCountryCode: Código ISO 3166-1 alpha-2 del país del paciente (ej. "ES", "AR").
    ///                     Se usa solo cuando el número no incluye indicativo explícito.
    static func normalizedForWhatsApp(_ raw: String, isoCountryCode: String? = nil) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        let digits: String
        if trimmed.hasPrefix("+") {
            // Formato internacional con +: el indicativo ya está incluido
            digits = trimmed.dropFirst().filter(\.isNumber)
        } else if trimmed.hasPrefix("00") {
            // Formato internacional europeo con 00: quitar el prefijo marcador
            digits = String(trimmed.dropFirst(2)).filter(\.isNumber)
        } else {
            // Número local: intentar anteponer indicativo del país
            let localDigits = trimmed.filter(\.isNumber)
            if let iso = isoCountryCode, let code = dialCode(forISO: iso) {
                digits = code + localDigits
            } else {
                digits = localDigits
            }
        }

        guard digits.count >= 7 else { return nil }
        return digits
    }

    // MARK: - Indicativos por país

    /// Devuelve el indicativo telefónico internacional para un código ISO 3166-1 alpha-2.
    /// Cubre los países de mayor uso clínico en el contexto hispanoamericano y europeo.
    static func dialCode(forISO iso: String) -> String? {
        dialCodes[iso.uppercased()]
    }

    // MARK: - Detección de WhatsApp

    /// Verdadero si WhatsApp está instalado y puede ser invocado en este dispositivo.
    /// Requiere que "whatsapp" esté declarado en LSApplicationQueriesSchemes (Info.plist).
    static var isWhatsAppAvailable: Bool {
        guard let url = URL(string: "whatsapp://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - Construcción de URLs

    /// Construye la URL de deep link wa.me para abrir una conversación de WhatsApp.
    /// - Parameters:
    ///   - normalizedPhone: Número ya normalizado (solo dígitos con código de país, sin +).
    ///   - message: Texto preformateado opcional. Vacío por defecto (reservado para uso futuro).
    /// - Returns: URL lista para UIApplication.open, o nil si la construcción falla.
    static func whatsAppURL(normalizedPhone: String, message: String = "") -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wa.me"
        components.path = "/\(normalizedPhone)"
        if !message.isEmpty {
            components.queryItems = [URLQueryItem(name: "text", value: message)]
        }
        return components.url
    }

    /// Construye la URL tel:// para iniciar una llamada telefónica.
    /// Preserva el símbolo + del código de país si está presente.
    static func callURL(for rawPhone: String) -> URL? {
        let digits = rawPhone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        let cleaned = rawPhone.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+")
            ? "+\(digits)"
            : digits
        return URL(string: "tel://\(cleaned)")
    }

    // MARK: - Tabla de indicativos

    /// Indicativos ITU-T E.164 indexados por código ISO 3166-1 alpha-2.
    /// Hispanoamérica, España, Portugal y países de alta frecuencia clínica global.
    private static let dialCodes: [String: String] = [
        // Hispanoamérica
        "AR": "54",
        "MX": "52",
        "CO": "57",
        "CL": "56",
        "PE": "51",
        "VE": "58",
        "EC": "593",
        "GT": "502",
        "CU": "53",
        "BO": "591",
        "DO": "1",
        "HN": "504",
        "PY": "595",
        "SV": "503",
        "NI": "505",
        "CR": "506",
        "PA": "507",
        "UY": "598",
        "PR": "1",
        // Europa hispanohablante y de referencia clínica
        "ES": "34",
        "PT": "351",
        "DE": "49",
        "FR": "33",
        "IT": "39",
        "GB": "44",
        // Norteamérica
        "US": "1",
        "CA": "1",
        // Brasil
        "BR": "55",
    ]
}
