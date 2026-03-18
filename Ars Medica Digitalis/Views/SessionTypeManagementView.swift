//
//  SessionTypeManagementView.swift
//  Ars Medica Digitalis
//
//  Hoja para editar el nombre o dar de baja un tipo facturable.
//

import SwiftUI
import SwiftData

struct SessionTypeManagementView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SessionTypeManagementViewModel
    @State private var errorMessage: String?
    @State private var showingArchiveConfirmation = false

    private let onChanged: @MainActor () async -> Void

    init(
        snapshot: SessionTypeBusinessSnapshot,
        professional: Professional,
        context: ModelContext,
        onChanged: @escaping @MainActor () async -> Void = {}
    ) {
        _viewModel = State(
            initialValue: SessionTypeManagementViewModel(
                snapshot: snapshot,
                professional: professional,
                context: context
            )
        )
        self.onChanged = onChanged
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $viewModel.name)
                        .textInputAutocapitalization(.words)

                    Picker("Moneda", selection: $viewModel.currencyCode) {
                        ForEach(CurrencyCatalog.common) { currency in
                            Text(currency.displayLabel).tag(currency.code)
                        }
                    }

                    TextField(
                        "Valor vigente",
                        value: $viewModel.price,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)

                    DatePicker(
                        "Vigente desde",
                        selection: $viewModel.effectiveFrom,
                        displayedComponents: .date
                    )
                } header: {
                    Text("Tipo de sesión")
                } footer: {
                    Text(identityFooterText)
                }

                Section {
                    SessionTypeStylePicker(
                        previewName: viewModel.name,
                        previewPrice: previewPriceText,
                        selectedColorToken: $viewModel.colorToken,
                        selectedSymbolName: $viewModel.symbolName
                    )
                } header: {
                    Text("Apariencia")
                } footer: {
                    Text("El color y el SF Symbol quedan persistidos para reutilizarlos en agenda, sesiones y reportes.")
                }

                Section {
                    Button("Eliminar tipo", role: .destructive) {
                        showingArchiveConfirmation = true
                    }
                } header: {
                    Text("Acciones")
                } footer: {
                    Text("Se da de baja del catálogo operativo y conserva el historial de precios y sesiones.")
                }
            }
            .navigationTitle("Administrar tipo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(viewModel.canSave == false)
                }
            }
        }
        .confirmationDialog(
            "¿Eliminar este tipo de sesión?",
            isPresented: $showingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task {
                    await archive()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El tipo dejará de aparecer en sesiones nuevas, pero el historial se conserva.")
        }
        .alert("No se pudo guardar", isPresented: $errorMessage.isPresent) {
            Button("Aceptar", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Ocurrió un error al actualizar el tipo.")
        }
    }

    @MainActor
    private func save() async {
        do {
            try viewModel.save()
            dismiss()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func archive() async {
        do {
            try viewModel.archive()
            dismiss()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var previewPriceText: String {
        viewModel.price > 0
        ? viewModel.price.formattedCurrency(code: viewModel.currencyCode)
        : "Sin honorario cargado"
    }

    private var identityFooterText: String {
        let baseText = "Guardar crea una nueva versión manual si cambiás valor, moneda o vigencia."
        if viewModel.isSuggestedDefault {
            return "\(baseText) Este tipo está configurado como sugerido para sesiones nuevas."
        }

        return baseText
    }
}
