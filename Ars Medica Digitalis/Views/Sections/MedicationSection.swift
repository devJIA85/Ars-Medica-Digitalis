//
//  MedicationSection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct MedicationSection: View {

    let patient: Patient
    let onShowMedicationInfo: (Medication) -> Void

    var body: some View {
        CardContainer(
            title: "Medicación",
            systemImage: "pills",
            style: .flat
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if sortedCurrentMedications.isEmpty {
                    if patient.currentMedication.trimmed.isEmpty {
                        ClinicalEmptyState(text: "Sin medicación registrada")
                    } else {
                        ClinicalMetricTile(title: "Texto libre", value: patient.currentMedication)
                    }
                } else {
                    ForEach(sortedCurrentMedications) { medication in
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(medication.primaryDisplayName)
                                    .font(.body.weight(.semibold))

                                Text(medication.secondaryDisplayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            Button {
                                onShowMedicationInfo(medication)
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Ver información de \(medication.summaryLabel)")
                        }

                        if medication.id != sortedCurrentMedications.last?.id {
                            Divider()
                        }
                    }

                    if !patient.currentMedication.trimmed.isEmpty {
                        ClinicalMetricTile(title: "Observaciones", value: patient.currentMedication)
                    }
                }
            }
        }
    }

    private var sortedCurrentMedications: [Medication] {
        (patient.currentMedications ?? []).sorted {
            if $0.principioActivo.caseInsensitiveCompare($1.principioActivo) == .orderedSame {
                return $0.nombreComercial.localizedCaseInsensitiveCompare($1.nombreComercial) == .orderedAscending
            }
            return $0.principioActivo.localizedCaseInsensitiveCompare($1.principioActivo) == .orderedAscending
        }
    }
}
