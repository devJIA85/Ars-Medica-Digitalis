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
        CardContainer(
            title: "Resumen del paciente",
            systemImage: "person.text.rectangle",
            style: .elevated
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    PatientAvatarView(
                        photoData: patient.photoData,
                        firstName: patient.firstName,
                        lastName: patient.lastName,
                        genderHint: patient.gender.isEmpty ? patient.biologicalSex : patient.gender,
                        clinicalStatus: patient.clinicalStatus,
                        size: 60
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(patient.fullName)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        Text("\(patient.age) años")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !patient.medicalRecordNumber.isEmpty {
                            Text(patient.medicalRecordNumber)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                }

                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(summaryItems, id: \.title) { item in
                        ClinicalMetricTile(title: item.title, value: item.value)
                    }
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
