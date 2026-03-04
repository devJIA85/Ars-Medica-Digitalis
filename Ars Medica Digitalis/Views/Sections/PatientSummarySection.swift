//
//  PatientSummarySection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct PatientSummarySection: View {

    let patient: Patient

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md, alignment: .leading),
        GridItem(.flexible(), spacing: AppSpacing.md, alignment: .leading)
    ]

    var body: some View {
        SectionCard(
            title: "Datos del paciente",
            icon: "person.text.rectangle"
        ) {
            LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                ForEach(summaryItems, id: \.title) { item in
                    ClinicalMetric(title: item.title, value: item.value, style: .material)
                }
            }
        }
    }

    private var summaryItems: [(title: String, value: String)] {
        var items: [(String, String)] = [
            ("Nacimiento", patient.dateOfBirth.esShortDateAbbrev()),
            ("Sexo biológico", displayValue(patient.biologicalSex)),
            ("Género", displayValue(patient.gender)),
            ("Ocupación", displayValue(patient.occupation))
        ]

        if !patient.healthInsurance.trimmed.isEmpty {
            items.append(("Cobertura", patient.healthInsurance))
        }

        return items
    }

    private func displayValue(_ rawValue: String) -> String {
        let trimmedValue = rawValue.trimmed
        return trimmedValue.isEmpty ? "No registrado" : trimmedValue
    }
}
