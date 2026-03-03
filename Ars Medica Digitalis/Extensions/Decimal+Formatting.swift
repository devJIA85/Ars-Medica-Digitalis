import Foundation

extension Decimal {
    /// Formatea importes con código ISO cuando la moneda existe.
    /// Esto evita conversiones implícitas y mantiene visible la moneda
    /// real con la que se registró la sesión o el pago.
    func formattedCurrency(code: String) -> String {
        guard !code.isEmpty else {
            return NSDecimalNumber(decimal: self).stringValue
        }

        return self.formatted(.currency(code: code).presentation(.isoCode))
    }

    /// Formatea un valor fraccional como porcentaje legible para UI.
    /// Se usa en honorarios para mostrar IPC acumulado sin duplicar
    /// configuración de NumberFormatter dentro de cada vista.
    func formattedPercent(maximumFractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = .autoupdatingCurrent
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self))
            ?? NSDecimalNumber(decimal: self).stringValue
    }
}
