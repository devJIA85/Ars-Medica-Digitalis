//
//  PatientSummarySection.swift
//  Ars Medica Digitalis
//
//  Datos del paciente — layout Health.app: etiqueta fija (secundaria) + valor (primario).
//  Grid auto-dimensiona la columna de etiquetas al texto más largo.
//  Sin íconos: las etiquetas ya identifican cada campo.
//

import SwiftUI

struct PatientSummarySection: View {

    let patient: Patient

    var body: some View {
        SectionCard(title: "Datos del paciente", icon: "person.text.rectangle", prominence: .secondary) {
            Grid(alignment: .leading, horizontalSpacing: AppSpacing.md, verticalSpacing: 0) {

                dataRow("Nacimiento", patient.dateOfBirth.compactDashboardDate)

                Divider()

                dataRow("DNI", displayValue(patient.nationalId))

                Divider()

                dataRow("Ocupación", displayValue(patient.occupation))

                if !patient.healthInsurance.trimmed.isEmpty {
                    Divider()
                    dataRow("Cobertura", patient.healthInsurance)
                }

                if !patient.insuranceMemberNumber.trimmed.isEmpty {
                    Divider()
                    dataRow("Afiliado", patient.insuranceMemberNumber)
                }

                if !patient.insurancePlan.trimmed.isEmpty {
                    Divider()
                    dataRow("Plan", patient.insurancePlan)
                }

                if let addr = addressValue {
                    Divider()
                    dataRow("Dirección", addr)
                }
            }
        }
    }

    // MARK: - Row builder

    private func dataRow(_ label: String, _ value: String) -> some View {
        GridRow(alignment: .center) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
                .padding(.vertical, 10)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .padding(.vertical, 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    // MARK: - Helpers

    private func displayValue(_ raw: String) -> String {
        let trimmed = raw.trimmed
        return trimmed.isEmpty ? "No registrado" : trimmed
    }

    private var addressValue: String? {
        let address = patient.address.trimmed
        let flag = patient.residenceCountry.flagEmoji
        if address.isEmpty && flag == nil { return nil }
        let parts = [address.isEmpty ? nil : address, flag].compactMap { $0 }
        return parts.joined(separator: " ")
    }
}

private extension Date {
    var compactDashboardDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: self)
    }
}
