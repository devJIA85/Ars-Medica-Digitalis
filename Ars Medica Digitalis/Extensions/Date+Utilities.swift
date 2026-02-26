import Foundation

extension Date {
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
}
