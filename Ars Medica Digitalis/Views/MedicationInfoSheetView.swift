//
//  MedicationInfoSheetView.swift
//  Ars Medica Digitalis
//
//  Ficha completa de un medicamento del vademécum local.
//

import SwiftUI

struct MedicationInfoSheetView: View {

    let medication: Medication

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.primaryDisplayName)
                        .font(.headline)
                    Text(medication.secondaryDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Detalle") {
                LabeledContent("Principio activo", value: valueOrDash(medication.principioActivo))
                LabeledContent("Nombre comercial", value: valueOrDash(medication.nombreComercial))
                LabeledContent("Potencia", value: valueOrDash(medication.potencia))
                LabeledContent("Potencia valor", value: valueOrDash(medication.potenciaValor))
                LabeledContent("Potencia unidad", value: valueOrDash(medication.potenciaUnidad))
                LabeledContent("Contenido", value: valueOrDash(medication.contenido))
                LabeledContent("Presentacion", value: valueOrDash(medication.presentacion))
                LabeledContent("Laboratorio", value: valueOrDash(medication.laboratorio))
                LabeledContent("Origen", value: medication.isUserCreated ? "Local" : "Vademécum")
            }
        }
        .navigationTitle("Medicamento")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func valueOrDash(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value
    }
}
