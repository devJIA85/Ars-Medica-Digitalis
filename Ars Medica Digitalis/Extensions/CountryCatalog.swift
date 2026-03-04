//
//  CountryCatalog.swift
//  Ars Medica Digitalis
//
//  Catálogo de países basado en ISO 3166-1 alpha-2.
//  Genera la lista completa a partir de Locale.Region.isoRegions
//  con nombres localizados en es_AR para el picker de formularios.
//

import Foundation

struct CountryItem: Identifiable, Sendable {
    let code: String      // ISO 3166-1 alpha-2 ("AR")
    let name: String      // Nombre localizado ("Argentina")
    let flag: String      // Emoji bandera ("🇦🇷")

    var id: String { code }

    var displayLabel: String { "\(flag) \(name)" }
}

enum CountryCatalog {

    /// País fijo al inicio del picker (Argentina)
    static let pinnedCode = "AR"

    // MARK: - Catálogo completo

    /// Todos los países con nombre localizado en es_AR, ordenados alfabéticamente.
    /// Se genera una sola vez (lazy) a partir de las regiones ISO del sistema.
    static let all: [CountryItem] = {
        let locale = Locale(identifier: "es_AR")
        return Locale.Region.isoRegions
            .compactMap { region -> CountryItem? in
                let code = region.identifier
                // Filtrar códigos que no son países (regiones especiales de 3+ chars)
                guard code.count == 2 else { return nil }
                guard let name = locale.localizedString(forRegionCode: code),
                      !name.isEmpty else { return nil }
                guard let flag = emojiFlag(fromRegionCode: code) else { return nil }
                return CountryItem(code: code, name: name, flag: flag)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    // MARK: - Búsqueda

    /// Busca un país por código ISO
    static func item(for code: String) -> CountryItem? {
        let uppercased = code.uppercased()
        return all.first { $0.code == uppercased }
    }

    /// Display label legible para un código ISO.
    /// Retrocompatible: si el código es un nombre completo (datos legacy),
    /// intenta resolverlo buscando por nombre.
    static func displayName(for code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Sin especificar" }

        // Camino rápido: código ISO de 2 letras
        if let country = item(for: trimmed) {
            return country.displayLabel
        }

        // Fallback: el valor guardado es un nombre completo (datos legacy)
        if let country = itemByName(trimmed) {
            return country.displayLabel
        }

        // Último recurso: devolver el texto tal cual
        return trimmed
    }

    // MARK: - Países frecuentes dinámicos

    /// Top N países más usados en nationality y residenceCountry de los pacientes.
    /// Excluye el país fijo (AR) y valores vacíos.
    static func frequentCodes(from patients: [Patient], limit: Int = 5) -> [String] {
        var frequency: [String: Int] = [:]
        let pinned = pinnedCode

        for patient in patients where patient.isActive {
            for raw in [patient.nationality, patient.residenceCountry] {
                let code = resolveCode(raw)
                guard !code.isEmpty, code != pinned else { continue }
                frequency[code, default: 0] += 1
            }
        }

        return frequency
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }

    // MARK: - Resolución de código

    /// Convierte un valor guardado (ISO code o nombre legacy) a código ISO.
    /// Útil para normalizar datos existentes.
    static func resolveCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Ya es código ISO
        if trimmed.count == 2 {
            let upper = trimmed.uppercased()
            if item(for: upper) != nil { return upper }
        }

        // Es nombre completo → buscar código
        if let country = itemByName(trimmed) {
            return country.code
        }

        return trimmed
    }

    // MARK: - Privado

    /// Busca un país por nombre localizado (insensible a caso y diacríticos).
    /// Para retrocompatibilidad con datos almacenados como texto libre.
    private static func itemByName(_ name: String) -> CountryItem? {
        let locales = [
            Locale(identifier: "es_AR"),
            Locale(identifier: "en_US"),
            Locale.current
        ]

        for code in Locale.Region.isoRegions.map(\.identifier) where code.count == 2 {
            for locale in locales {
                if let localizedName = locale.localizedString(forRegionCode: code),
                   localizedName.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                    return item(for: code)
                }
            }
        }

        return nil
    }

    /// Convierte código de región ISO a emoji de bandera
    private static func emojiFlag(fromRegionCode regionCode: String) -> String? {
        let uppercased = regionCode.uppercased()
        guard uppercased.count == 2 else { return nil }

        let base: UInt32 = 127397
        let scalars = uppercased.unicodeScalars.compactMap { scalar -> UnicodeScalar? in
            UnicodeScalar(base + scalar.value)
        }

        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }
}
