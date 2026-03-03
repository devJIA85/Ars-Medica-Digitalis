import Foundation

extension Date {
    /// Normaliza una fecha administrativa al inicio de su día.
    /// En honorarios "vigente desde" es una regla por fecha, no por hora,
    /// así evitamos que un precio cargado hoy quede inválido para sesiones
    /// del mismo día que ocurren más temprano.
    func startOfDayDate(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    /// Normaliza una fecha al inicio exacto del minuto.
    /// Se usa para validar conflictos de agenda sin arrastrar segundos
    /// residuales que podrían romper un filtro por igualdad temporal.
    func startOfMinuteDate(calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .minute, for: self)?.start ?? self
    }

    /// Toma el año/mes/día de self y la hora/minuto de `source`.
    /// Útil para combinar una fecha del calendario con la hora actual.
    func combiningTimeFrom(_ source: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: source)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0
        return calendar.date(from: components) ?? self
    }

    func roundedToMinuteInterval(_ interval: Int, calendar: Calendar = .current) -> Date {
        guard interval > 0 else { return self }
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        guard let minute = components.minute else { return self }

        let rounded = Int((Double(minute) / Double(interval)).rounded()) * interval
        if rounded >= 60 {
            components.minute = 0
            if let hour = components.hour {
                components.hour = hour + 1
            }
        } else {
            components.minute = rounded
        }
        components.second = 0

        return calendar.date(from: components) ?? self
    }

    /// Resuelve la hora inicial de una sesión nueva creada desde calendario.
    /// Si la fecha fuente solo representa un día (00:00), usamos una hora
    /// neutral de consultorio para no empujar la carga al "ahora".
    /// Si la fecha ya trae hora explícita, la respetamos y solo la redondeamos.
    func defaultSessionStartDate(
        fallbackHour: Int = 9,
        fallbackMinute: Int = 0,
        calendar: Calendar = .current
    ) -> Date {
        let timeComponents = calendar.dateComponents([.hour, .minute], from: self)
        let hasExplicitTime = (timeComponents.hour ?? 0) != 0 || (timeComponents.minute ?? 0) != 0

        if hasExplicitTime {
            return roundedToMinuteInterval(5, calendar: calendar)
        }

        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = fallbackHour
        components.minute = fallbackMinute
        components.second = 0

        let resolved = calendar.date(from: components) ?? self
        return resolved.roundedToMinuteInterval(5, calendar: calendar)
    }
}
