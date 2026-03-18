//
//  PatientSessionFinancialListView.swift
//  Ars Medica Digitalis
//
//  Vista de finanzas centrada en sesiones.
//  Reemplaza el libro mayor de cargos+pagos mezclados por una lista
//  donde cada fila es una sesión y el estado de cobro es visible de inmediato.
//
//  Principio de diseño: un profesional debe poder responder en < 2 segundos
//  "¿está pagada esta sesión?" sin calcular mentalmente nada.
//

import SwiftData
import SwiftUI

// MARK: - View principal

struct PatientSessionFinancialListView: View {

    let patient: Patient

    @State private var selectedCurrency: String = ""
    @State private var selectedSession: Session? = nil

    private var availableCurrencies: [String] {
        FinancialLedgerBuilder.availableCurrencies(for: patient)
    }

    /// Sesiones completadas, no cortesía, con precio > 0, filtradas por moneda,
    /// ordenadas de más reciente a más antigua.
    private var financialSessions: [Session] {
        (patient.sessions ?? [])
            .filter { session in
                session.sessionStatusValue == .completada
                    && !session.isCourtesy
                    && resolvedCurrency(for: session) == selectedCurrency
                    && resolvedPrice(for: session) > 0
            }
            .sorted { lhs, rhs in
                (lhs.completedAt ?? lhs.sessionDate) > (rhs.completedAt ?? rhs.sessionDate)
            }
    }

    /// Deuda total en la moneda seleccionada.
    /// Reutiliza Patient.debtByCurrency para consistencia con el resto de la app.
    private var totalDebt: Decimal {
        patient.debtByCurrency
            .first { $0.currencyCode == selectedCurrency }
            .map(\.debt) ?? 0
    }

    var body: some View {
        CardContainer(style: .flat) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {

                // Encabezado con moneda activa
                HStack(alignment: .firstTextBaseline) {
                    Text("Finanzas")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    if !selectedCurrency.isEmpty {
                        Text(selectedCurrency)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Selector de moneda: solo visible cuando hay más de una
                if availableCurrencies.count > 1 {
                    Picker("Moneda", selection: $selectedCurrency) {
                        ForEach(availableCurrencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Balance global: deuda total o "cuenta al día"
                if !selectedCurrency.isEmpty {
                    balanceHeader
                }

                Divider()

                // Lista de sesiones
                if financialSessions.isEmpty {
                    Text(emptyMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(financialSessions.enumerated()), id: \.element.id) { index, session in
                            Button {
                                selectedSession = session
                            } label: {
                                SessionFinancialRow(
                                    session: session,
                                    currencyCode: selectedCurrency
                                )
                            }
                            .buttonStyle(.plain)

                            if index < financialSessions.count - 1 {
                                Divider()
                                    .padding(.leading, 36)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            initializeCurrencyIfNeeded()
        }
        .onChange(of: availableCurrencies) { _, newCurrencies in
            if !newCurrencies.contains(selectedCurrency) {
                selectedCurrency = newCurrencies.first ?? ""
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionPaymentBreakdownView(
                session: session,
                currencyCode: selectedCurrency
            )
        }
    }

    // MARK: - Subvistas

    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(totalDebt > 0 ? "Deuda total" : "Cuenta al día")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                totalDebt > 0
                    ? totalDebt.formattedCurrency(code: selectedCurrency)
                    : "Sin deuda pendiente"
            )
            .font(.title2.weight(.bold))
            .foregroundStyle(totalDebt > 0 ? Color.orange : Color.green)
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.25), value: totalDebt)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(totalDebt > 0 ? "Deuda total" : "Cuenta al día")
        .accessibilityValue(
            totalDebt > 0
                ? totalDebt.formattedCurrency(code: selectedCurrency)
                : "Sin deuda pendiente"
        )
    }

    // MARK: - Helpers

    private var emptyMessage: String {
        selectedCurrency.isEmpty
            ? "Sin sesiones facturables registradas."
            : "Sin sesiones facturables en \(selectedCurrency)."
    }

    private func initializeCurrencyIfNeeded() {
        guard selectedCurrency.isEmpty else { return }
        selectedCurrency = availableCurrencies.first ?? ""
    }

    private func resolvedCurrency(for session: Session) -> String {
        if let currency = session.finalCurrencySnapshot, !currency.isEmpty {
            return currency
        }
        return session.effectiveCurrency
    }

    private func resolvedPrice(for session: Session) -> Decimal {
        if let snapshot = session.finalPriceSnapshot, snapshot > 0 { return snapshot }
        return session.resolvedPrice > 0 ? session.resolvedPrice : 0
    }
}

// MARK: - Fila de sesión

private struct SessionFinancialRow: View {

    let session: Session
    let currencyCode: String

    private var sessionDate: Date { session.completedAt ?? session.sessionDate }

    private var price: Decimal {
        if let s = session.finalPriceSnapshot, s > 0 { return s }
        return session.resolvedPrice > 0 ? session.resolvedPrice : 0
    }

    private var remaining: Decimal {
        let r = price - session.totalPaid
        return r > 0 ? r : 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Ícono de estado — tamaño fijo para alinear columnas
            Image(systemName: session.paymentStateSymbol)
                .font(.body)
                .foregroundStyle(session.paymentStateColor)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {

                // Tipo de sesión + badge de estado en la misma línea
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(session.financialTypeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Badge de estado: color semántico inmediato
                    Text(session.paymentStateLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(session.paymentStateColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            session.paymentStateColor.opacity(0.12),
                            in: Capsule()
                        )
                }

                // Fecha
                Text(sessionDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Chips financieros: pendiente (prominente si > 0), total, cobrado
                HStack(alignment: .top, spacing: 14) {
                    if remaining > 0 {
                        financialChip(
                            label: "Pendiente",
                            value: remaining.formattedCurrency(code: currencyCode),
                            valueColor: session.paymentStateColor
                        )
                    }

                    financialChip(
                        label: "Total",
                        value: price.formattedCurrency(code: currencyCode),
                        valueColor: .primary
                    )

                    if session.totalPaid > 0 {
                        financialChip(
                            label: "Cobrado",
                            value: session.totalPaid.formattedCurrency(code: currencyCode),
                            valueColor: .green
                        )
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func financialChip(
        label: String,
        value: String,
        valueColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
        }
    }

    private var accessibilityLabel: String {
        let dateStr = sessionDate.formatted(date: .abbreviated, time: .omitted)
        let priceStr = price.formattedCurrency(code: currencyCode)
        let remainStr = remaining > 0
            ? ", pendiente \(remaining.formattedCurrency(code: currencyCode))"
            : ""
        return "\(session.financialTypeLabel), \(dateStr), \(session.paymentStateLabel). Total \(priceStr)\(remainStr)."
    }
}

// MARK: - Detalle de cobros por sesión (drill-down)

struct SessionPaymentBreakdownView: View {

    @Environment(\.dismiss) private var dismiss

    let session: Session
    let currencyCode: String

    private var price: Decimal {
        if let s = session.finalPriceSnapshot, s > 0 { return s }
        return session.resolvedPrice > 0 ? session.resolvedPrice : 0
    }

    private var sortedPayments: [Payment] {
        (session.payments ?? []).sorted { $0.paidAt < $1.paidAt }
    }

    var body: some View {
        NavigationStack {
            List {
                // Resumen de la sesión
                Section("Sesión") {
                    LabeledContent("Tipo", value: session.financialTypeLabel)
                    LabeledContent(
                        "Fecha",
                        value: (session.completedAt ?? session.sessionDate)
                            .formatted(date: .long, time: .omitted)
                    )
                    LabeledContent("Total", value: price.formattedCurrency(code: currencyCode))
                    LabeledContent(
                        "Cobrado",
                        value: session.totalPaid.formattedCurrency(code: currencyCode)
                    )
                    LabeledContent("Estado") {
                        Text(session.paymentStateLabel)
                            .foregroundStyle(session.paymentStateColor)
                            .font(.subheadline.weight(.semibold))
                    }
                }

                // Deuda pendiente: visible solo cuando existe
                if session.debt > 0 {
                    Section {
                        LabeledContent("Pendiente") {
                            Text(session.debt.formattedCurrency(code: currencyCode))
                                .foregroundStyle(.orange)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                // Lista de pagos individuales
                Section(sortedPayments.isEmpty ? "Pagos" : "Pagos (\(sortedPayments.count))") {
                    if sortedPayments.isEmpty {
                        Text("Sin pagos registrados.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedPayments) { payment in
                            paymentRow(payment)
                        }
                    }
                }
            }
            .navigationTitle("Detalle financiero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func paymentRow(_ payment: Payment) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.paidAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if !payment.notes.isEmpty {
                    Text(payment.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(payment.amount.formattedCurrency(code: payment.currencyCode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pago de \(payment.amount.formattedCurrency(code: payment.currencyCode)) el \(payment.paidAt.formatted(date: .abbreviated, time: .omitted))")
    }
}

// MARK: - Helpers de presentación sobre Session

/// Propiedades de visualización financiera aisladas en esta capa de UI.
/// Se declaran fileprivate para no contaminar el modelo con lógica de display.
@MainActor fileprivate extension Session {

    /// Nombre legible del tipo de sesión, priorizando el catálogo financiero.
    var financialTypeLabel: String {
        if let name = financialSessionType?.name, !name.isEmpty { return name }
        switch sessionTypeValue {
        case .presencial:    return "Sesión presencial"
        case .videollamada:  return "Sesión por videollamada"
        case .telefonica:   return "Sesión telefónica"
        }
    }

    var paymentStateLabel: String {
        switch paymentState {
        case .unpaid:       return "Sin pagar"
        case .paidPartial:  return "Parcial"
        case .paidFull:     return "Pagada"
        }
    }

    var paymentStateColor: Color {
        switch paymentState {
        case .unpaid:       return .secondary
        case .paidPartial:  return .orange
        case .paidFull:     return .green
        }
    }

    var paymentStateSymbol: String {
        switch paymentState {
        case .unpaid:       return "circle.dotted"
        case .paidPartial:  return "circle.lefthalf.filled"
        case .paidFull:     return "checkmark.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        PatientSessionFinancialListView(
            patient: Patient(
                firstName: "Ana",
                lastName: "García"
            )
        )
        .padding()
    }
    .modelContainer(.preview)
}
