import Foundation

extension Date {
    /// Fecha y hora abreviadas en español, sin "at". Ej: "19 Feb 2026 17:54"
    func esShortDateTime(localeIdentifier: String = "es_AR") -> String {
        let dateStyle = Date.FormatStyle()
            .day(.twoDigits)
            .month(.abbreviated)
            .year(.defaultDigits)
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .locale(Locale(identifier: localeIdentifier))
        return self.formatted(dateStyle)
    }

    /// Solo fecha en español (abreviada). Ej: "19 Feb 2026"
    func esShortDate(localeIdentifier: String = "es_AR") -> String {
        let dateStyle = Date.FormatStyle()
            .day(.twoDigits)
            .month(.abbreviated)
            .year(.defaultDigits)
            .locale(Locale(identifier: localeIdentifier))
        return self.formatted(dateStyle)
    }

    /// Solo hora en español (24h). Ej: "17:54"
    func esShortTime(localeIdentifier: String = "es_AR") -> String {
        let timeStyle = Date.FormatStyle()
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .locale(Locale(identifier: localeIdentifier))
        return self.formatted(timeStyle)
    }

    /// Día y mes con mes abreviado en español. Ej: "18 Feb"
    func esDayMonthAbbrev(localeIdentifier: String = "es_AR") -> String {
        var style = Date.FormatStyle.dateTime
            .day(.twoDigits)
            .month(.abbreviated)
        style.locale = Locale(identifier: localeIdentifier)
        return self.formatted(style)
    }

    /// Fecha corta con mes abreviado y año. Ej: "18 Feb 2000"
    func esShortDateAbbrev(localeIdentifier: String = "es_AR") -> String {
        var style = Date.FormatStyle.dateTime
            .day(.twoDigits)
            .month(.abbreviated)
            .year(.defaultDigits)
        style.locale = Locale(identifier: localeIdentifier)
        return self.formatted(style)
    }
}
