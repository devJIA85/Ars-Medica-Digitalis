//
//  String+HTML.swift
//  Ars Medica Digitalis
//
//  La API del CIE-11 devuelve títulos con etiquetas <em> para resaltar
//  coincidencias de búsqueda. Esta extensión las limpia para mostrar
//  texto plano en la UI.
//

import Foundation

extension String {

    /// Elimina etiquetas <em ...> y </em> que la API CIE-11 usa para
    /// marcar coincidencias de búsqueda en los títulos devueltos.
    nonisolated func cleanedHTMLTags() -> String {
        var result = self
        if let regex = try? NSRegularExpression(pattern: "<em[^>]*>", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: ""
            )
        }
        result = result.replacingOccurrences(of: "</em>", with: "")
        return result
    }

    /// Elimina TODAS las etiquetas HTML del string.
    var withoutHTMLTags: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
