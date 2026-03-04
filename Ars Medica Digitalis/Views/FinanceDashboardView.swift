//
//  FinanceDashboardView.swift
//  Ars Medica Digitalis
//
//  Pantalla de finanzas del profesional.
//  Presenta métricas agregadas por moneda sin conversión y reutiliza
//  FinanceDashboardViewModel como única fuente de estado derivado.
//

import SwiftUI
import SwiftData

struct FinanceDashboardView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = FinanceDashboardViewModel()
    @State private var errorMessage: String?

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                if viewModel.availableCurrencies.isEmpty {
                    Section {
                        ContentUnavailableView(
                            L10n.tr("finance.dashboard.empty.title"),
                            systemImage: "chart.bar.doc.horizontal",
                            description: Text(L10n.tr("finance.dashboard.empty.description"))
                        )
                    }
                } else {
                    // Los controles se muestran solo cuando hay datos porque
                    // si no existen monedas disponibles no hay nada que filtrar.
                    Section(L10n.tr("finance.dashboard.filters")) {
                        currencySelector
                        monthSelector
                    }

                    // Cada KPI se muestra como bloque propio para mejorar lectura
                    // rápida en una pantalla de resumen financiero.
                    Section {
                        FinanceMetricCard(
                            title: L10n.tr("finance.dashboard.metric.collected_month"),
                            value: formattedAmount(viewModel.monthlyCollected),
                            systemImage: "creditcard.fill",
                            tint: .green,
                            valueTint: nil,
                            backgroundTint: nil
                        )
                    }

                    Section {
                        FinanceMetricCard(
                            title: L10n.tr("finance.dashboard.metric.accrued_month"),
                            value: formattedAmount(viewModel.monthlyAccrued),
                            systemImage: "calendar.badge.checkmark",
                            tint: .blue,
                            valueTint: nil,
                            backgroundTint: nil
                        )
                    }

                    Section {
                        FinanceMetricCard(
                            title: L10n.tr("finance.dashboard.metric.total_debt"),
                            value: formattedAmount(viewModel.totalDebt),
                            systemImage: "exclamationmark.triangle.fill",
                            tint: viewModel.totalDebt > 0 ? Color.red.opacity(0.76) : .orange,
                            valueTint: viewModel.totalDebt > 0 ? Color.red.opacity(0.82) : nil,
                            backgroundTint: viewModel.totalDebt > 0 ? Color.red.opacity(0.08) : nil
                        )
                    }

                    // La deuda por paciente se muestra como lista simple para
                    // priorizar legibilidad antes que navegación avanzada.
                    Section {
                        if viewModel.debtByPatient.isEmpty {
                            Text(L10n.tr("finance.dashboard.debt.empty"))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.debtByPatient) { summary in
                                NavigationLink {
                                    PatientDebtSettlementView(
                                        patient: summary.patient,
                                        context: modelContext,
                                        preferredCurrencyCode: viewModel.selectedCurrency
                                    )
                                } label: {
                                    debtRow(summary)
                                }
                            }
                        }
                    } header: {
                        debtSectionHeader
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(L10n.tr("finance.dashboard.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("finance.dashboard.close")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            refreshDashboard()
        }
        // El dashboard deriva todos sus totales desde SwiftData, así que
        // cualquier save relevante debe disparar un recálculo completo.
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            refreshDashboard()
        }
        .onChange(of: viewModel.selectedCurrency) { _, _ in
            refreshDashboard()
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            refreshDashboard()
        }
        .alert(L10n.tr("finance.dashboard.load_error.title"), isPresented: errorBinding) {
            Button(L10n.tr("common.accept"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? L10n.tr("finance.dashboard.load_error.message"))
        }
    }

    @ViewBuilder
    private var currencySelector: some View {
        @Bindable var viewModel = viewModel

        if viewModel.availableCurrencies.count == 1 {
            LabeledContent(L10n.tr("finance.dashboard.currency"), value: viewModel.selectedCurrency)
        } else if viewModel.availableCurrencies.count <= 3 {
            Picker(L10n.tr("finance.dashboard.currency"), selection: $viewModel.selectedCurrency) {
                ForEach(viewModel.availableCurrencies, id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
            .pickerStyle(.segmented)
        } else {
            Picker(L10n.tr("finance.dashboard.currency"), selection: $viewModel.selectedCurrency) {
                ForEach(viewModel.availableCurrencies, id: \.self) { currency in
                    Text(currency).tag(currency)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var monthSelector: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.tr("finance.dashboard.month.previous"))

            Spacer()

            VStack(spacing: 4) {
                Text(viewModel.selectedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)

                Button(L10n.tr("finance.dashboard.month.current")) {
                    goToCurrentMonth()
                }
                .font(.footnote)
                .disabled(isCurrentMonthSelected)
            }

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.tr("finance.dashboard.month.next"))
        }
    }

    /// El refresh se encapsula en la vista para que la UI solo reaccione a
    /// cambios de filtros y el cálculo siga centralizado en el ViewModel.
    @MainActor
    private func refreshDashboard() {
        do {
            try viewModel.refresh(in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: viewModel.selectedMonth) else {
            return
        }

        viewModel.selectedMonth = FinanceDashboardViewModel.normalizedMonth(
            newMonth,
            calendar: calendar
        )
    }

    private func goToCurrentMonth() {
        viewModel.selectedMonth = FinanceDashboardViewModel.normalizedMonth(
            Date(),
            calendar: calendar
        )
    }

    private var isCurrentMonthSelected: Bool {
        FinanceDashboardViewModel.normalizedMonth(viewModel.selectedMonth, calendar: calendar)
        == FinanceDashboardViewModel.normalizedMonth(Date(), calendar: calendar)
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        guard viewModel.selectedCurrency.isEmpty == false else {
            return L10n.tr("finance.dashboard.no_data")
        }

        return amount.formattedCurrency(code: viewModel.selectedCurrency)
    }

    /// El dashboard financiero siempre está filtrado por la moneda activa.
    /// El header lo explicita para evitar comparar este listado con la lista
    /// general de pacientes, que puede marcar deuda en otras monedas.
    @ViewBuilder
    private var debtSectionHeader: some View {
        let baseTitle = L10n.tr("finance.dashboard.debt.patients")

        if viewModel.selectedCurrency.isEmpty {
            Text(baseTitle)
        } else {
            let patientCount = viewModel.debtByPatient.count
            Text("\(baseTitle) · \(viewModel.selectedCurrency) · \(patientCount)")
        }
    }

    /// La fila reutilizable concentra la presentación de deuda y permite
    /// envolverla opcionalmente en NavigationLink sin duplicar layout.
    @ViewBuilder
    private func debtRow(_ summary: PatientDebtSummary) -> some View {
        LabeledContent(summary.patientName) {
            Text(formattedAmount(summary.debt))
                .fontWeight(.semibold)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    errorMessage = nil
                }
            }
        )
    }
}

private struct FinanceMetricCard: View {

    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    let valueTint: Color?
    let backgroundTint: Color?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(valueTint ?? .primary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(backgroundTint ?? .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    FinanceDashboardView()
        .modelContainer(.preview)
}
