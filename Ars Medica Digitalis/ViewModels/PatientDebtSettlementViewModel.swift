//
//  PatientDebtSettlementViewModel.swift
//  Ars Medica Digitalis
//
//  Gestiona el cobro de deuda acumulada a nivel paciente.
//  Distribuye el pago sobre sesiones completadas con saldo, siempre dentro
//  de una sola moneda por vez para respetar el modelo multi-moneda real.
//

import Foundation
import SwiftData

enum PatientDebtSettlementOption: String, CaseIterable, Identifiable, Sendable {
    case full
    case partial

    var id: String { rawValue }
}

enum PatientDebtSettlementError: LocalizedError {
    case noDebtAvailable
    case invalidPartialAmount

    var errorDescription: String? {
        switch self {
        case .noDebtAvailable:
            return "El paciente no tiene deuda pendiente en la moneda seleccionada."
        case .invalidPartialAmount:
            return "Ingresá un importe mayor a cero y menor o igual a la deuda pendiente."
        }
    }
}

@MainActor
@Observable
final class PatientDebtSettlementViewModel {

    private let patient: Patient
    private let context: ModelContext
    private let preferredCurrencyCode: String?

    var debtSummaries: [PatientDebtCurrencySummary] = []
    var selectedCurrency: String = "" {
        didSet {
            // Al cambiar de moneda se reinicia el borrador para evitar que un
            // parcial escrito para otra divisa termine aplicándose mal.
            if oldValue != selectedCurrency {
                selectedOption = .full
                partialAmount = 0
            }
        }
    }
    var selectedOption: PatientDebtSettlementOption = .full
    var partialAmount: Decimal = 0

    init(
        patient: Patient,
        context: ModelContext,
        preferredCurrencyCode: String? = nil
    ) {
        self.patient = patient
        self.context = context
        self.preferredCurrencyCode = preferredCurrencyCode
    }

    var patientName: String {
        patient.fullName
    }

    var selectedSummary: PatientDebtCurrencySummary? {
        debtSummaries.first { $0.currencyCode == selectedCurrency }
    }

    var totalDebt: Decimal {
        selectedSummary?.debt ?? 0
    }

    var pendingSessionsCount: Int {
        selectedSummary?.sessionCount ?? 0
    }

    var canConfirm: Bool {
        guard totalDebt > 0 else { return false }

        switch selectedOption {
        case .full:
            return true
        case .partial:
            return partialAmount > 0 && partialAmount <= totalDebt
        }
    }

    /// Relee la deuda desde SwiftData para evitar snapshots stale en UI.
    /// No persiste nada: solo expone el estado actual del paciente por moneda.
    func refresh() throws {
        let completedSessions = try fetchCompletedSessions()
        let summaries = buildDebtSummaries(from: completedSessions)
        debtSummaries = summaries

        guard summaries.isEmpty == false else {
            selectedCurrency = ""
            return
        }

        if let preferredCurrencyCode,
           summaries.contains(where: { $0.currencyCode == preferredCurrencyCode }),
           selectedCurrency.isEmpty {
            selectedCurrency = preferredCurrencyCode
            return
        }

        if summaries.contains(where: { $0.currencyCode == selectedCurrency }) == false {
            selectedCurrency = summaries[0].currencyCode
        }
    }

    /// Registra un pago total o parcial sobre la deuda acumulada seleccionada.
    /// El pago se reparte de la sesión más antigua a la más nueva para que el
    /// criterio sea estable, auditable y consistente entre ejecuciones.
    func registerPayment() throws {
        guard selectedCurrency.isEmpty == false, totalDebt > 0 else {
            throw PatientDebtSettlementError.noDebtAvailable
        }

        let amountToApply: Decimal
        switch selectedOption {
        case .full:
            amountToApply = totalDebt
        case .partial:
            guard partialAmount > 0, partialAmount <= totalDebt else {
                throw PatientDebtSettlementError.invalidPartialAmount
            }
            amountToApply = partialAmount
        }

        var remainingAmount = amountToApply
        let pendingSessions = try fetchPendingSessions(for: selectedCurrency)

        for session in pendingSessions where remainingAmount > 0 {
            let sessionDebt = session.debt
            guard sessionDebt > 0 else { continue }

            let paymentAmount = min(sessionDebt, remainingAmount)
            let payment = Payment(
                amount: paymentAmount,
                currencyCode: selectedCurrency,
                paidAt: Date(),
                session: session
            )
            context.insert(payment)
            remainingAmount -= paymentAmount
        }

        try context.save()
        selectedOption = .full
        partialAmount = 0
        try refresh()
    }

    private func fetchCompletedSessions() throws -> [Session] {
        let patientID = patient.id
        let completedStatus = SessionStatusMapping.completada.rawValue
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { session in
                session.patient?.id == patientID
                && (session.completedAt != nil || session.status == completedStatus)
            }
        )

        return try context.fetch(descriptor)
    }

    private func fetchPendingSessions(for currencyCode: String) throws -> [Session] {
        try fetchCompletedSessions()
            .filter { session in
                resolvedCurrency(for: session) == currencyCode && session.debt > 0
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.completedAt ?? lhs.sessionDate
                let rhsDate = rhs.completedAt ?? rhs.sessionDate

                if lhsDate == rhsDate {
                    return lhs.sessionDate < rhs.sessionDate
                }

                return lhsDate < rhsDate
            }
    }

    private func buildDebtSummaries(from sessions: [Session]) -> [PatientDebtCurrencySummary] {
        let groupedDebt = sessions.reduce(into: [String: (debt: Decimal, sessionCount: Int)]()) { partialResult, session in
            let debt = session.debt
            let currencyCode = resolvedCurrency(for: session)
            guard debt > 0, currencyCode.isEmpty == false else { return }

            let currentDebt = partialResult[currencyCode]?.debt ?? 0
            let currentCount = partialResult[currencyCode]?.sessionCount ?? 0
            partialResult[currencyCode] = (
                debt: currentDebt + debt,
                sessionCount: currentCount + 1
            )
        }

        return groupedDebt.map { currencyCode, value in
            PatientDebtCurrencySummary(
                currencyCode: currencyCode,
                debt: value.debt,
                sessionCount: value.sessionCount
            )
        }
        .sorted { lhs, rhs in
            if lhs.debt == rhs.debt {
                return lhs.currencyCode < rhs.currencyCode
            }
            return lhs.debt > rhs.debt
        }
    }

    private func resolvedCurrency(for session: Session) -> String {
        session.finalCurrencySnapshot ?? session.effectiveCurrency
    }
}
