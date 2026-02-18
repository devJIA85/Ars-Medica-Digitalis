//
//  CalendarViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel para la vista de calendario de sesiones.
//  Gestiona la navegación entre meses, la carga de sesiones
//  por rango de fechas y la selección de días.
//

import Foundation
import SwiftData

@Observable
final class CalendarViewModel {

    // MARK: - Estado del calendario

    /// Mes actualmente visible. Se usa solo año+mes para la grilla.
    var displayedMonth: Date = Date()

    /// Día seleccionado por el usuario (nil = ninguno seleccionado).
    var selectedDate: Date? = nil

    /// Sesiones del mes visible, cargadas desde SwiftData.
    var sessionsInMonth: [Session] = []

    // MARK: - Navegación entre meses

    func goToPreviousMonth() {
        displayedMonth = Calendar.current.date(
            byAdding: .month, value: -1, to: displayedMonth
        ) ?? displayedMonth
    }

    func goToNextMonth() {
        displayedMonth = Calendar.current.date(
            byAdding: .month, value: 1, to: displayedMonth
        ) ?? displayedMonth
    }

    func goToToday() {
        displayedMonth = Date()
        selectedDate = Date()
    }

    // MARK: - Carga de sesiones

    /// Carga todas las sesiones dentro del mes visible.
    /// Usa #Predicate con rango de fechas para eficiencia.
    func loadSessions(in context: ModelContext) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)

        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
        else { return }

        let predicate = #Predicate<Session> { session in
            session.sessionDate >= startOfMonth
            && session.sessionDate < endOfMonth
        }

        let descriptor = FetchDescriptor<Session>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.sessionDate)]
        )

        do {
            sessionsInMonth = try context.fetch(descriptor)
        } catch {
            sessionsInMonth = []
        }
    }

    // MARK: - Computed: sesiones del día seleccionado

    /// Sesiones filtradas para el día seleccionado, ordenadas por hora.
    var sessionsForSelectedDate: [Session] {
        guard let selected = selectedDate else { return [] }
        let calendar = Calendar.current
        return sessionsInMonth.filter {
            calendar.isDate($0.sessionDate, inSameDayAs: selected)
        }
    }

    // MARK: - Computed: días con sesiones

    /// Set de números de día (1-31) que tienen al menos una sesión.
    /// Usado para mostrar puntos indicadores en la grilla del calendario.
    var daysWithSessions: Set<Int> {
        let calendar = Calendar.current
        return Set(sessionsInMonth.map {
            calendar.component(.day, from: $0.sessionDate)
        })
    }

    /// Diccionario [día: cantidad de sesiones] para mostrar múltiples puntos indicadores.
    var sessionCountsByDay: [Int: Int] {
        let calendar = Calendar.current
        var counts: [Int: Int] = [:]
        for session in sessionsInMonth {
            let day = calendar.component(.day, from: session.sessionDate)
            counts[day, default: 0] += 1
        }
        return counts
    }

    // MARK: - Helpers de calendario

    /// Genera las celdas del mes como array de Optional<Int>.
    /// nil = celda vacía (offset del primer día), Int = número de día.
    /// La semana empieza en lunes (estándar en Argentina/España).
    func calendarDays() -> [Int?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)

        guard let firstDayOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)
        else { return [] }

        // Día de la semana del 1ro del mes, ajustado para que Lunes = 0
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offset = (weekday + 5) % 7

        var days: [Int?] = Array(repeating: nil, count: offset)
        days += range.map { Optional($0) }

        return days
    }

    /// Construye un Date a partir de un número de día en el mes visible.
    func date(forDay day: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: displayedMonth)
        components.day = day
        return calendar.date(from: components) ?? displayedMonth
    }

    /// Verifica si un día del mes es hoy.
    func isToday(_ day: Int) -> Bool {
        Calendar.current.isDateInToday(date(forDay: day))
    }

    /// Verifica si un día del mes es el seleccionado.
    func isSelected(_ day: Int) -> Bool {
        guard let selected = selectedDate else { return false }
        return Calendar.current.isDate(date(forDay: day), inSameDayAs: selected)
    }
}
