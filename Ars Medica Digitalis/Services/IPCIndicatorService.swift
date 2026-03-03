//
//  IPCIndicatorService.swift
//  Ars Medica Digitalis
//
//  Mock determinístico del proveedor de IPC.
//  En este PR no consulta red: solo entrega un acumulado reproducible para tests.
//

import Foundation

@MainActor
final class IPCIndicatorService {

    private let calendar: Calendar
    private let monthlyRate: Decimal

    init(
        calendar: Calendar = .current,
        monthlyRate: Decimal = Decimal(string: "0.03") ?? .zero
    ) {
        self.calendar = calendar
        self.monthlyRate = monthlyRate
    }

    /// Devuelve el IPC acumulado entre dos fechas con una implementación mock.
    /// Se mantiene async/throws para que el contrato ya coincida con un cliente
    /// real futuro, pero hoy responde localmente con 3% mensual simple.
    func accumulatedIPC(from start: Date, to end: Date) async throws -> Decimal {
        let months = max(0, calendar.dateComponents([.month], from: start, to: end).month ?? 0)
        return Decimal(months) * monthlyRate
    }
}
