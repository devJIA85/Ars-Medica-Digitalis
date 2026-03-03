import Foundation

/// Catálogo corto de monedas frecuentes para la capa de captura.
/// Centralizamos esta lista para no hardcodear códigos ISO 4217 en múltiples
/// pantallas y para poder ampliarla o volverla configurable después.
struct SupportedCurrency: Identifiable, Equatable, Sendable {
    let code: String
    let name: String

    var id: String { code }

    var displayLabel: String {
        "\(code) · \(name)"
    }
}

enum CurrencyCatalog {
    static let common: [SupportedCurrency] = [
        SupportedCurrency(code: "ARS", name: "Peso argentino"),
        SupportedCurrency(code: "USD", name: "Dolar estadounidense"),
        SupportedCurrency(code: "EUR", name: "Euro"),
        SupportedCurrency(code: "BRL", name: "Real brasileno"),
        SupportedCurrency(code: "CLP", name: "Peso chileno"),
        SupportedCurrency(code: "MXN", name: "Peso mexicano"),
        SupportedCurrency(code: "UYU", name: "Peso uruguayo"),
    ]

    static func label(for code: String) -> String {
        common.first(where: { $0.code == code })?.displayLabel ?? code
    }
}
