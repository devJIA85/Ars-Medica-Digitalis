//
//  HonorariumCreateView.swift
//  Ars Medica Digitalis
//
//  Alta mínima de un honorario operativo.
//  Permite cargar nombre, moneda y precio base para destrabar el circuito.
//

import SwiftUI
import SwiftData

struct HonorariumCreateView: View {

    @Environment(\.dismiss) private var dismiss

    let professional: Professional
    let context: ModelContext
    let onCreated: @MainActor () async -> Void

    @State private var viewModel = HonorariumCreateViewModel()
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Honorario") {
                    TextField("Nombre", text: $viewModel.name)

                    Picker("Moneda", selection: $viewModel.currencyCode) {
                        ForEach(CurrencyCatalog.common) { currency in
                            Text(currency.displayLabel).tag(currency.code)
                        }
                    }

                    TextField(
                        "Precio",
                        value: $viewModel.price,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)

                    DatePicker(
                        "Vigente desde",
                        selection: $viewModel.effectiveFrom,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("Nuevo honorario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(viewModel.canSave == false)
                }
            }
        }
        .alert("No se pudo crear el honorario", isPresented: errorBinding) {
            Button("Aceptar", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Ocurrió un error al guardar el honorario.")
        }
    }

    /// Persistimos primero y refrescamos el tablero al final para que la hoja
    /// se cierre con la lista ya recompuesta, sin lógica de negocio en la vista.
    @MainActor
    private func save() async {
        do {
            try viewModel.save(for: professional, in: context)
            dismiss()
            await onCreated()
        } catch {
            errorMessage = error.localizedDescription
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
