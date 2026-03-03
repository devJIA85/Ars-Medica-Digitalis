import Foundation

enum L10n {
    /// Resuelve una key simple del String Catalog sin interpolación adicional.
    /// Se mantiene esta API mínima para los textos estáticos ya existentes.
    static func tr(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    /// Resuelve una key del String Catalog y aplica placeholders estilo
    /// `String(format:)` para que la UI pueda reutilizar textos localizados
    /// sin concatenar fragmentos manuales en cada vista.
    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = tr(key)
        return String(format: format, locale: Locale.autoupdatingCurrent, arguments: arguments)
    }
}
