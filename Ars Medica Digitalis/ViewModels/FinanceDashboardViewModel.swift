//
//  FinanceDashboardViewModel.swift
//  Ars Medica Digitalis
//
//  Calcula métricas financieras agregadas sin conversión de moneda.
//  Separa cobrado, devengado y deuda por currencyCode para preservar
//  la trazabilidad real de cada sesión y cada pago.
//

import Foundation
import SwiftData

/// Representa el período visible del dashboard financiero.
/// Hoy solo necesitamos mes calendario, pero se modela como enum para
/// crecer luego sin cambiar el contrato externo del ViewModel.
enum FinancePeriod: Sendable, Equatable {
    case month(year: Int, month: Int)
}

/// Resumen de deuda agrupado por paciente para ranking financiero.
/// Conserva la referencia real al Patient para habilitar drill-down futuro
/// sin tener que volver a consultar SwiftData desde la vista.
struct PatientDebtSummary: Identifiable {
    let patient: Patient
    let patientName: String
    let debt: Decimal

    var id: UUID { patient.id }
}

@MainActor
@Observable
final class FinanceDashboardViewModel {

    var selectedCurrency: String = ""
    var availableCurrencies: [String] = []
    /// Siempre se normaliza al primer día del mes para evitar ambigüedad
    /// entre navegación visual y rango real usado en las queries.
    var selectedMonth: Date

    var monthlyCollected: Decimal = 0
    var monthlyAccrued: Decimal = 0
    var totalDebt: Decimal = 0
    var debtByPatient: [PatientDebtSummary] = []

    private let calendar: Calendar

    init(
        selectedMonth: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.calendar = calendar
        self.selectedMonth = Self.normalizedMonth(selectedMonth, calendar: calendar)
    }

    /// Recalcula todo el dashboard a partir del estado persistido actual.
    /// Es idempotente: solo lee SwiftData y reescribe propiedades derivadas
    /// del ViewModel, por lo que puede llamarse repetidamente sin efectos extra.
    func refresh(in context: ModelContext) throws {
        selectedMonth = Self.normalizedMonth(selectedMonth, calendar: calendar)

        // No convertimos monedas porque cada total debe respetar la moneda
        // histórica con la que se registraron sesiones y pagos.
        let currencies = try resolveAvailableCurrencies(in: context)
        availableCurrencies = currencies

        guard let resolvedCurrency = resolveSelectedCurrency(from: currencies) else {
            selectedCurrency = ""
            resetMetrics()
            return
        }

        selectedCurrency = resolvedCurrency

        let range = Self.monthRange(for: selectedMonth, calendar: calendar)
        let collectedPayments = try fetchPayments(
            currencyCode: resolvedCurrency,
            start: range.start,
            end: range.end,
            in: context
        )
        monthlyCollected = sumDecimals(collectedPayments) { $0.amount }

        let monthlyCompletedSessions = try fetchCompletedSessions(
            currencyCode: resolvedCurrency,
            start: range.start,
            end: range.end,
            in: context
        )
        monthlyAccrued = sumDecimals(monthlyCompletedSessions) { resolvedAccruedAmount(for: $0) }

        let patients = try fetchPatients(in: context)
        debtByPatient = buildDebtSummaries(
            from: patients,
            currencyCode: resolvedCurrency
        )
        totalDebt = sumDecimals(debtByPatient) { $0.debt }
    }

    /// Mes lógico actualmente visible por el dashboard.
    /// Permite desacoplar la fecha seleccionada de la representación de período.
    var selectedPeriod: FinancePeriod {
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        return .month(
            year: components.year ?? 0,
            month: components.month ?? 1
        )
    }

    /// Devuelve el rango semiabierto [inicio, fin) del mes dado.
    /// Se usa este formato para evitar dobles conteos en cambios de mes.
    static func monthRange(for date: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let start = normalizedMonth(date, calendar: calendar)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }

    /// Normaliza cualquier fecha al primer instante del mes visible.
    /// Esto evita que un día intermedio altere el rango usado por refresh.
    static func normalizedMonth(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func resetMetrics() {
        monthlyCollected = 0
        monthlyAccrued = 0
        totalDebt = 0
        debtByPatient = []
    }

    private func resolveSelectedCurrency(from currencies: [String]) -> String? {
        guard currencies.isEmpty == false else { return nil }

        if currencies.contains(selectedCurrency) {
            return selectedCurrency
        }

        return currencies.first
    }

    private func resolveAvailableCurrencies(in context: ModelContext) throws -> [String] {
        let paymentCurrencies = try fetchPaymentCurrencies(in: context)
        let sessionCurrencies = try fetchCompletedSessionCurrencies(in: context)
        let patientDebtCurrencies = try fetchPatientDebtCurrencies(in: context)
        return Array(
            Set(paymentCurrencies)
                .union(sessionCurrencies)
                .union(patientDebtCurrencies)
        )
        .sorted()
    }

    private func fetchPaymentCurrencies(in context: ModelContext) throws -> [String] {
        let descriptor = FetchDescriptor<Payment>(
            predicate: #Predicate<Payment> { payment in
                payment.currencyCode != ""
            }
        )

        return try context.fetch(descriptor)
            .map(\.currencyCode)
    }

    private func fetchCompletedSessionCurrencies(in context: ModelContext) throws -> [String] {
        let completedStatus = SessionStatusMapping.completada.rawValue
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.completedAt != nil || session.status == completedStatus
            }
        )

        return try context.fetch(descriptor)
            .map(resolvedCurrency(for:))
            .filter { $0.isEmpty == false }
    }

    /// El selector de moneda también debe reflejar deudas visibles en Perfil.
    /// Así evitamos que una moneda con deuda reconstruible por paciente quede
    /// fuera del dashboard solo porque la sesión histórica no tiene todos los
    /// snapshots financieros completos.
    private func fetchPatientDebtCurrencies(in context: ModelContext) throws -> [String] {
        try fetchPatients(in: context)
            .flatMap(\.debtByCurrency)
            .map(\.currencyCode)
            .filter { $0.isEmpty == false }
    }

    /// Payment es la única fuente de verdad para cobrado.
    /// SwiftData no expone SUM, por eso fetchamos el conjunto filtrado y
    /// sumamos en memoria con un helper genérico reutilizable.
    private func fetchPayments(
        currencyCode: String,
        start: Date,
        end: Date,
        in context: ModelContext
    ) throws -> [Payment] {
        let descriptor = FetchDescriptor<Payment>(
            predicate: #Predicate<Payment> { payment in
                payment.currencyCode == currencyCode
                && payment.paidAt >= start
                && payment.paidAt < end
            }
        )

        return try context.fetch(descriptor)
    }

    /// Las sesiones completadas son la fuente de verdad para devengado y deuda.
    /// Filtramos por completedAt y moneda snapshot para respetar historia
    /// contable real, sin recalcular sobre la moneda vigente actual.
    private func fetchCompletedSessions(
        currencyCode: String,
        in context: ModelContext
    ) throws -> [Session] {
        let completedStatus = SessionStatusMapping.completada.rawValue
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.completedAt != nil || session.status == completedStatus
            }
        )

        return try context.fetch(descriptor).filter { session in
            resolvedCurrency(for: session) == currencyCode
        }
    }

    private func fetchCompletedSessions(
        currencyCode: String,
        start: Date,
        end: Date,
        in context: ModelContext
    ) throws -> [Session] {
        // SwiftData no soporta forced unwrap dentro de #Predicate para Date?,
        // por eso filtramos con predicate la población ya completada y luego
        // recortamos el mes en memoria usando el helper de rango.
        let completedSessions = try fetchCompletedSessions(
            currencyCode: currencyCode,
            in: context
        )
        return completedSessions.filter { session in
            let reportingDate = resolvedCompletedDate(for: session)
            return reportingDate >= start && reportingDate < end
        }
    }

    /// El ranking por paciente se arma desde Patient.debtByCurrency para que
    /// Finanzas reutilice exactamente la misma lectura fresca que usa Perfil
    /// y el flujo de cancelación de deuda.
    private func fetchPatients(in context: ModelContext) throws -> [Patient] {
        let impossibleID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let descriptor = FetchDescriptor<Patient>(
            predicate: #Predicate<Patient> { patient in
                patient.id != impossibleID
            }
        )

        return try context.fetch(descriptor)
    }

    /// Algunas sesiones completadas históricas pueden no tener snapshot de moneda
    /// porque fueron creadas antes del cierre financiero definitivo. El dashboard
    /// usa el mismo fallback que Perfil para no ocultar deuda real del paciente.
    private func resolvedCurrency(for session: Session) -> String {
        if let finalCurrency = session.finalCurrencySnapshot, finalCurrency.isEmpty == false {
            return finalCurrency
        }

        return session.effectiveCurrency
    }

    /// Algunas sesiones antiguas fueron cerradas con status completada pero sin
    /// completedAt persistido. Para no perderlas en deuda/devengado mensual,
    /// usamos sessionDate como fallback histórico del mes de imputación.
    private func resolvedCompletedDate(for session: Session) -> Date {
        session.completedAt ?? session.sessionDate
    }

    /// El devengado mensual debe seguir la misma compatibilidad histórica.
    /// Si falta snapshot de precio, reutilizamos el precio efectivo visible.
    private func resolvedAccruedAmount(for session: Session) -> Decimal {
        session.finalPriceSnapshot ?? session.effectivePrice
    }

    /// Agrupa deuda por paciente usando el resumen ya consolidado del modelo.
    /// Esto evita divergencias entre la ficha del paciente y el dashboard cuando
    /// existen sesiones históricas con snapshots incompletos pero deuda vigente.
    private func buildDebtSummaries(
        from patients: [Patient],
        currencyCode: String
    ) -> [PatientDebtSummary] {
        patients.compactMap { patient in
            guard let summary = patient.debtByCurrency.first(where: { $0.currencyCode == currencyCode }) else {
                return nil
            }

            guard summary.debt > 0 else { return nil }

            let patientName = patient.fullName.isEmpty
                ? L10n.tr("finance.dashboard.patient.unknown")
                : patient.fullName

            return PatientDebtSummary(
                patient: patient,
                patientName: patientName,
                debt: summary.debt
            )
        }
        .sorted { lhs, rhs in
            if lhs.debt == rhs.debt {
                return lhs.patientName < rhs.patientName
            }
            return lhs.debt > rhs.debt
        }
    }

    private func sumDecimals<Element>(
        _ elements: [Element],
        using extractor: (Element) -> Decimal
    ) -> Decimal {
        elements.reduce(0) { partialResult, element in
            partialResult + extractor(element)
        }
    }
}
