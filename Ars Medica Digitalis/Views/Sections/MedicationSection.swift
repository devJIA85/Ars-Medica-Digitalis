//
//  MedicationSection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct MedicationSection: View {

    let patient: Patient
    let onEditMedicalHistory: () -> Void
    let onShowMedicationInfo: (Medication) -> Void

    var body: some View {
        SectionCard(
            title: "Medicación",
            icon: "pills"
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if sortedCurrentMedications.isEmpty {
                    if patient.currentMedication.trimmed.isEmpty {
                        EmptyStateView(
                            message: "Sin medicación registrada",
                            buttonTitle: "Agregar medicación",
                            action: onEditMedicalHistory
                        )
                    } else {
                        ClinicalListRow(
                            icon: "text.justify",
                            title: "Texto libre",
                            value: patient.currentMedication,
                            onTap: onEditMedicalHistory,
                            onDelete: deleteLegacyMedication,
                            onEdit: onEditMedicalHistory
                        )
                    }
                } else {
                    ForEach(sortedCurrentMedications) { medication in
                        ClinicalListRow(
                            icon: "pills",
                            title: medication.primaryDisplayName,
                            value: medication.secondaryDisplayName,
                            onTap: {
                                onShowMedicationInfo(medication)
                            },
                            onDelete: {
                                deleteMedication(medication)
                            },
                            onEdit: onEditMedicalHistory
                        )

                        if medication.id != sortedCurrentMedications.last?.id {
                            Divider()
                        }
                    }

                    if !patient.currentMedication.trimmed.isEmpty {
                        ClinicalListRow(
                            icon: "text.justify",
                            title: "Observaciones",
                            value: patient.currentMedication,
                            onTap: onEditMedicalHistory,
                            onDelete: deleteLegacyMedication,
                            onEdit: onEditMedicalHistory
                        )
                    }
                }
            }
        }
    }

    private var sortedCurrentMedications: [Medication] {
        patient.currentMedications.sorted {
            if $0.principioActivo.caseInsensitiveCompare($1.principioActivo) == .orderedSame {
                return $0.nombreComercial.localizedCaseInsensitiveCompare($1.nombreComercial) == .orderedAscending
            }
            return $0.principioActivo.localizedCaseInsensitiveCompare($1.principioActivo) == .orderedAscending
        }
    }

    private func deleteMedication(_ medication: Medication) {
        patient.currentMedications = patient.currentMedications.filter { $0.id != medication.id }
        patient.updatedAt = Date()
    }

    private func deleteLegacyMedication() {
        patient.currentMedication = ""
        patient.updatedAt = Date()
    }
}
