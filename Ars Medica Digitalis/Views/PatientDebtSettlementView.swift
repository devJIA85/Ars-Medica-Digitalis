//
//  PatientDebtSettlementView.swift
//  Ars Medica Digitalis
//
//  Pantalla única para cancelar deuda acumulada del paciente.
//  Reutiliza Payment como única fuente de verdad y evita crear una lógica
//  paralela de saldos manuales por fuera de las sesiones completadas.
//

import SwiftUI
import SwiftData

struct PatientDebtSettlementView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PatientDebtSettlementViewModel
    @State private var errorMessage: String?

    let showsCloseButton: Bool

    init(
        patient: Patient,
        context: ModelContext,
        preferredCurrencyCode: String? = nil,
        showsCloseButton: Bool = false
    ) {
        _viewModel = State(
            initialValue: PatientDebtSettlementViewModel(
                patient: patient,
                context: context,
                preferredCurrencyCode: preferredCurrencyCode
            )
        )
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            if viewModel.debtSummaries.isEmpty {
                ContentUnavailableView(
                    L10n.tr("patient.debt.settlement.empty.title"),
                    systemImage: "checkmark.circle",
                    description: Text(L10n.tr("patient.debt.settlement.empty.description"))
                )
            } else {
                Section {
                    if viewModel.debtSummaries.count > 1 {
                        Picker(L10n.tr("Moneda"), selection: $viewModel.selectedCurrency) {
                            ForEach(viewModel.debtSummaries) { summary in
                                Text(summary.currencyCode).tag(summary.currencyCode)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        LabeledContent(L10n.tr("Moneda"), value: viewModel.selectedCurrency)
                    }

                    LabeledContent(L10n.tr("patient.debt.settlement.total")) {
                        Text(totalDebtText)
                            .fontWeight(.semibold)
                    }

                    LabeledContent(L10n.tr("Sesiones")) {
                        Text("\(viewModel.pendingSessionsCount)")
                    }
                } header: {
                    Text(L10n.tr("Resumen"))
                } footer: {
                    Text(L10n.tr("patient.debt.settlement.distribution_footer"))
                }

                Section {
                    ForEach(PatientDebtSettlementOption.allCases) { option in
                        settlementOptionRow(option)
                    }

                    if viewModel.selectedOption == .partial {
                        TextField(
                            L10n.tr("patient.debt.settlement.partial_amount"),
                            value: $viewModel.partialAmount,
                            format: .number.precision(.fractionLength(2))
                        )
                        .keyboardType(.decimalPad)

                        Text(L10n.tr("patient.debt.settlement.partial_footer"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(L10n.tr("patient.debt.settlement.payment_section"))
                }
            }
        }
        .navigationTitle(L10n.tr("patient.debt.settlement.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.tr("patient.debt.settlement.confirm")) {
                    confirm()
                }
                .disabled(viewModel.canConfirm == false)
            }
        }
        .task {
            refresh()
        }
        .alert(L10n.tr("patient.debt.settlement.error.title"), isPresented: errorBinding) {
            Button(L10n.tr("common.accept"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? L10n.tr("patient.debt.settlement.error.generic"))
        }
    }

    private var totalDebtText: String {
        guard viewModel.selectedCurrency.isEmpty == false else {
            return L10n.tr("patient.debt.settlement.no_currency")
        }

        return viewModel.totalDebt.formattedCurrency(code: viewModel.selectedCurrency)
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

    /// La vista solo dispara acciones del ViewModel.
    /// Si el pago se registró correctamente se vuelve a la pantalla anterior
    /// para mantener el flujo corto tanto desde Perfil como desde Finanzas.
    @MainActor
    private func confirm() {
        do {
            try viewModel.registerPayment()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refresh() {
        do {
            try viewModel.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func settlementOptionRow(_ option: PatientDebtSettlementOption) -> some View {
        Button {
            viewModel.selectedOption = option
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(optionTitle(option))
                        .foregroundStyle(.primary)

                    Text(optionDescription(option))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 12)

                Image(systemName: viewModel.selectedOption == option ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(viewModel.selectedOption == option ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func optionTitle(_ option: PatientDebtSettlementOption) -> String {
        switch option {
        case .full:
            return L10n.tr("patient.debt.settlement.option.full.title")
        case .partial:
            return L10n.tr("patient.debt.settlement.option.partial.title")
        }
    }

    private func optionDescription(_ option: PatientDebtSettlementOption) -> String {
        switch option {
        case .full:
            return L10n.tr("patient.debt.settlement.option.full.description")
        case .partial:
            return L10n.tr("patient.debt.settlement.option.partial.description")
        }
    }
}
