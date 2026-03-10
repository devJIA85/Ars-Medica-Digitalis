//
//  PaymentFlowView.swift
//  Ars Medica Digitalis
//
//  Sheet nativa para cerrar una sesión con o sin cobro.
//  La vista solo captura la intención del usuario; la persistencia real
//  se delega al ViewModel para mantener una única fuente de verdad.
//

import SwiftUI

private enum PaymentOption: String, CaseIterable, Identifiable {
    case full
    case partial
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "Pagó todo"
        case .partial: "Pagó una parte"
        case .none: "No pagó"
        }
    }

    var description: String {
        switch self {
        case .full: "Registra el cobro completo de la sesión."
        case .partial: "Permite ingresar un monto parcial mayor a cero."
        case .none: "No registra cobro y deja la deuda total."
        }
    }
}

struct PaymentFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPartialAmountFocused: Bool

    let draft: CompletionDraft
    let onCancel: @MainActor () -> Void
    let onConfirm: @MainActor (PaymentIntent) async throws -> Void

    @State private var selectedOption: PaymentOption = .full
    @State private var partialAmount: Decimal = 0
    @State private var errorMessage: String?
    @State private var isConfirming = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let configurationIssue = draft.configurationIssue {
                        configurationWarning(
                            message: configurationIssue.message(
                                resolvedCurrencyCode: draft.currencyCode
                            )
                        )
                    }

                    LabeledContent("Moneda del paciente", value: currencySummaryText)
                    LabeledContent("Total resuelto", value: totalSummaryText)

                    if draft.isCourtesy {
                        HStack {
                            Text("Tipo")
                            Spacer()
                            Text("Cortesía")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                } header: {
                    Text("Resumen")
                } footer: {
                    if draft.isCourtesy == false, draft.configurationIssue == nil {
                        Text("La moneda no se elige acá: viene del paciente. El total se resuelve con el tipo facturable y el honorario vigente.")
                    }
                }

                if draft.isCourtesy == false, draft.isFinanciallyConfigured {
                    Section {
                        ForEach(PaymentOption.allCases) { option in
                            paymentOptionRow(for: option)
                        }

                        if selectedOption == .partial {
                            TextField(
                                "Monto cobrado",
                                value: $partialAmount,
                                format: .number.precision(.fractionLength(2))
                            )
                            .keyboardType(.decimalPad)
                            .focused($isPartialAmountFocused)

                            Text("Ingresá un importe mayor a cero y menor al total.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Forma de cobro")
                    }
                }
            }
            .navigationTitle(draft.isCourtesy ? "Completar cortesía" : "Completar sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        confirm()
                    }
                    .disabled(canConfirm == false || isConfirming)
                }
            }
            .alert("No se pudo completar la sesión", isPresented: errorBinding) {
                Button("Aceptar", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Ocurrió un error al registrar el cierre.")
            }
            .interactiveDismissDisabled()
            .onAppear {
                if draft.isCourtesy == false, selectedOption == .partial {
                    isPartialAmountFocused = true
                }
            }
            .onChange(of: selectedOption) { _, newValue in
                if newValue == .partial {
                    isPartialAmountFocused = true
                }
            }
        }
    }

    /// Convierte la selección de UI al contrato que entiende el ViewModel.
    /// La vista no escribe pagos: solo entrega una intención ya validada.
    private var resolvedIntent: PaymentIntent {
        if draft.isCourtesy {
            return .none
        }

        switch selectedOption {
        case .full:
            return .full
        case .partial:
            return .partial(partialAmount)
        case .none:
            return .none
        }
    }

    private var canConfirm: Bool {
        if draft.isFinanciallyConfigured == false {
            return false
        }

        if draft.isCourtesy {
            return true
        }

        switch selectedOption {
        case .full, .none:
            return true
        case .partial:
            return partialAmount > 0 && partialAmount < draft.amountDue
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

    @MainActor
    private func confirm() {
        guard draft.isFinanciallyConfigured || draft.isCourtesy else {
            return
        }

        guard isConfirming == false else {
            return
        }

        isConfirming = true

        Task { @MainActor in
            defer {
                isConfirming = false
            }

            do {
                try await onConfirm(resolvedIntent)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var currencySummaryText: String {
        if draft.isCourtesy {
            return draft.currencyCode.isEmpty ? "No aplica" : draft.currencyCode
        }

        return draft.currencyCode.isEmpty ? "Sin configurar" : draft.currencyCode
    }

    private var totalSummaryText: String {
        if draft.isCourtesy == false, draft.configurationIssue == .missingResolvedPrice,
           draft.currencyCode.isEmpty == false {
            return L10n.tr("session.pricing.unresolved_for_currency", draft.currencyCode)
        }

        if draft.isCourtesy == false, draft.configurationIssue != nil {
            return "Sin configurar"
        }

        if draft.currencyCode.isEmpty {
            return draft.amountDue == 0 ? "Sin configurar" : NSDecimalNumber(decimal: draft.amountDue).stringValue
        }

        return draft.amountDue.formattedCurrency(code: draft.currencyCode)
    }

    private func configurationWarning(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Falta configuración financiera", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Cuando eso esté configurado, el total y la forma de cobro se habilitan automáticamente.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func paymentOptionRow(for option: PaymentOption) -> some View {
        Button {
            selectedOption = option
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .foregroundStyle(.primary)
                    Text(option.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 12)

                Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedOption == option ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaymentFlowView(
        draft: CompletionDraft(
            sessionID: UUID(),
            amountDue: 120,
            currencyCode: "USD",
            isCourtesy: false,
            configurationIssue: nil
        ),
        onCancel: {},
        onConfirm: { _ in }
    )
}
