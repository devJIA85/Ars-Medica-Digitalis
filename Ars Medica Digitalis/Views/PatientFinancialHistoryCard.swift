//
//  PatientFinancialHistoryCard.swift
//  Ars Medica Digitalis
//
//  Card de historial financiero del paciente: muestra cargos y cobros cronológicamente
//  con saldo acumulado por moneda. Derivado en vivo desde Session + Payment,
//  sin almacenar estado redundante propio.
//

import SwiftUI
import SwiftData

struct PatientFinancialHistoryCard: View {

    let patient: Patient

    @State private var selectedCurrency: String = ""

    private var availableCurrencies: [String] {
        FinancialLedgerBuilder.availableCurrencies(for: patient)
    }

    /// Entradas del libro mayor en orden más reciente primero para escaneo rápido.
    private var entries: [FinancialLedgerEntry] {
        FinancialLedgerBuilder.entries(for: patient, currencyCode: selectedCurrency).reversed()
    }

    private var currentBalance: Decimal {
        // El primer elemento de la lista invertida es el más reciente → tiene el saldo final.
        entries.first?.runningBalance ?? 0
    }

    var body: some View {
        CardContainer(style: .flat) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {

                // Encabezado
                HStack(alignment: .firstTextBaseline) {
                    Text("Historial financiero")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    if !selectedCurrency.isEmpty {
                        Text(selectedCurrency)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Selector de moneda (solo cuando hay más de una)
                if availableCurrencies.count > 1 {
                    Picker("Moneda", selection: $selectedCurrency) {
                        ForEach(availableCurrencies, id: \.self) { currency in
                            Text(currency).tag(currency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Saldo actual destacado
                if !selectedCurrency.isEmpty {
                    balanceHeader
                }

                Divider()

                // Lista de movimientos — altura limitada para no colapsar el scroll padre
                if entries.isEmpty {
                    Text("Sin movimientos registrados en \(selectedCurrency.isEmpty ? "esta moneda" : selectedCurrency).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                ledgerRow(entry)

                                if index < entries.count - 1 {
                                    Divider()
                                        .padding(.leading, 36)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 420)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .onAppear {
            initializeCurrencyIfNeeded()
        }
        .onChange(of: availableCurrencies) { _, newCurrencies in
            // Si la moneda seleccionada ya no está disponible, resetear
            if !newCurrencies.contains(selectedCurrency) {
                selectedCurrency = newCurrencies.first ?? ""
            }
        }
    }

    // MARK: - Subviews

    /// Saldo actual del paciente en la moneda seleccionada.
    /// Verde cuando no debe, naranja/rojo cuando hay deuda pendiente.
    private var balanceHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Saldo actual")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(currentBalance.formattedCurrency(code: selectedCurrency))
                .font(.title2.weight(.bold))
                .foregroundColor(balanceColor)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: currentBalance)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saldo actual")
        .accessibilityValue(currentBalance.formattedCurrency(code: selectedCurrency))
    }

    private func ledgerRow(_ entry: FinancialLedgerEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {

            // Ícono del tipo de movimiento
            Image(systemName: entry.kind == .charge ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.body)
                .foregroundStyle(entry.kind == .charge ? Color.secondary : Color.green)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(entry.date.esShortDate())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                // Importe con signo según tipo
                Text(formattedAmount(entry))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(entry.kind == .charge ? Color.primary : Color.green)
                    .monospacedDigit()

                // Saldo acumulado tras este movimiento
                Text("Saldo: \(entry.runningBalance.formattedCurrency(code: entry.currencyCode))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: entry))
    }

    // MARK: - Helpers

    private var balanceColor: Color {
        if currentBalance <= 0 { return .green }
        return .orange
    }

    private func formattedAmount(_ entry: FinancialLedgerEntry) -> String {
        let prefix = entry.kind == .payment ? "-" : "+"
        return "\(prefix)\(entry.amount.formattedCurrency(code: entry.currencyCode))"
    }

    private func accessibilityLabel(for entry: FinancialLedgerEntry) -> String {
        let typeDescription = entry.kind == .charge ? "Cargo" : "Pago"
        let formattedDate = entry.date.esShortDate()
        let formattedAmount = entry.amount.formattedCurrency(code: entry.currencyCode)
        return "\(typeDescription) de \(formattedAmount) el \(formattedDate). Saldo: \(entry.runningBalance.formattedCurrency(code: entry.currencyCode))"
    }

    private func initializeCurrencyIfNeeded() {
        guard selectedCurrency.isEmpty else { return }
        selectedCurrency = availableCurrencies.first ?? ""
    }
}

#Preview {
    ScrollView {
        PatientFinancialHistoryCard(
            patient: Patient(
                firstName: "Ana",
                lastName: "García",
                dateOfBirth: Date()
            )
        )
        .padding()
    }
    .modelContainer(.preview)
}

