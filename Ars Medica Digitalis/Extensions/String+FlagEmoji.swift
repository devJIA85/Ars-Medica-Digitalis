//
//  String+FlagEmoji.swift
//  Ars Medica Digitalis
//
//  Extensión compartida para convertir un código ISO de país o nombre
//  de país en su emoji de bandera correspondiente.
//  Reemplaza las implementaciones duplicadas que existían en
//  ClinicalDashboardView y PatientSummarySection.
//

import Foundation

extension String {

    /// Convierte un valor de país (código ISO 2 letras o nombre completo)
    /// a su emoji de bandera. Nil si no se puede resolver.
    var flagEmoji: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Camino rápido: código ISO de 2 letras
        if trimmed.count == 2 {
            return Self.emojiFlag(fromRegionCode: trimmed)
        }

        // Fallback: nombre completo → buscar código en múltiples locales
        let locales = [
            Locale(identifier: "es_AR"),
            Locale(identifier: "en_US"),
            Locale.current
        ]

        for code in Locale.Region.isoRegions.map(\.identifier) where code.count == 2 {
            for locale in locales {
                if let localizedName = locale.localizedString(forRegionCode: code),
                   localizedName.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                    return Self.emojiFlag(fromRegionCode: code)
                }
            }
        }

        return nil
    }

    /// Convierte un código de región ISO 3166-1 alpha-2 a emoji de bandera
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
