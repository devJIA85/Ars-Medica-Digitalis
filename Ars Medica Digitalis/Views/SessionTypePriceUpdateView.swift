//
//  SessionTypePriceUpdateView.swift
//  Ars Medica Digitalis
//
//  Hoja de confirmación consciente para aplicar una nueva versión de honorario.
//  Muestra contexto económico y permite editar el importe antes de guardar.
//

import SwiftUI
import SwiftData

struct SessionTypePriceUpdateView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SessionTypePriceUpdateViewModel
    @State private var errorMessage: String?

    /// Callback del tablero superior.
    /// Se ejecuta luego de persistir la nueva versión para refrescar snapshots
    /// sin acoplar esta hoja a ningún ViewModel externo concreto.
    private let onApplied: @MainActor () async -> Void

    init(
        snapshot: SessionTypeBusinessSnapshot,
        professional: Professional,
        context: ModelContext,
        onApplied: @escaping @MainActor () async -> Void = {}
    ) {
        _viewModel = State(
            initialValue: SessionTypePriceUpdateViewModel(
                snapshot: snapshot,
                professional: professional,
                context: context
            )
        )
        self.onApplied = onApplied
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    LabeledContent(L10n.tr("honorarios.update_current_price")) {
                        Text(
                            viewModel.currentPrice.formattedCurrency(
                                code: viewModel.currentCurrencyCode
                            )
                        )
                    }

                    LabeledContent(L10n.tr("honorarios.ipc_accumulated_label")) {
                        Text(viewModel.ipcAccumulated.formattedPercent())
                    }

                    LabeledContent(L10n.tr("honorarios.update_suggested_price")) {
                        Text(
                            viewModel.suggestedPrice.formattedCurrency(
                                code: viewModel.currentCurrencyCode
                            )
                        )
                    }
                } header: {
                    Text(viewModel.sessionTypeName)
                }

                Section {
                    TextField(
                        L10n.tr("honorarios.update_editable_price"),
                        value: $viewModel.editablePrice,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(L10n.tr("honorarios.update_sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("honorarios.update_confirm")) {
                        Task {
                            await confirmUpdate()
                        }
                    }
                    .disabled(viewModel.canApply == false)
                }
            }
        }
        .alert(L10n.tr("honorarios.update_error.title"), isPresented: $errorMessage.isPresent) {
            Button(L10n.tr("common.accept"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? L10n.tr("honorarios.update_error.message"))
        }
    }

    /// Guarda la nueva versión y luego refresca el tablero superior.
    /// El orden importa: primero persistimos, después cerramos la hoja y por
    /// último pedimos recálculo para que la pantalla vuelva ya actualizada.
    @MainActor
    private func confirmUpdate() async {
        do {
            try viewModel.applyUpdate()
            dismiss()
            await onApplied()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

