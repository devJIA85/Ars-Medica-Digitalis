//
//  TreatmentsSection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct TreatmentsSection: View {

    let patient: Patient
    let onAddTreatment: () -> Void
    let onDeleteTreatment: (PriorTreatment) -> Void

    var body: some View {
        SectionCard(
            title: "Tratamientos",
            icon: "cross.case",
            action: {
                Button(action: onAddTreatment) {
                    Label("Agregar", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agregar tratamiento")
            }
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if sortedTreatments.isEmpty {
                    EmptyStateView(
                        message: "Sin tratamientos registrados",
                        buttonTitle: "Agregar tratamiento",
                        action: onAddTreatment
                    )
                } else {
                    TreatmentTimeline(treatments: sortedTreatments) { treatment in
                        PriorTreatmentFormView(patient: patient, treatment: treatment)
                    } onDelete: { treatment in
                        onDeleteTreatment(treatment)
                    }
                }
            }
        }
    }

    private var sortedTreatments: [PriorTreatment] {
        (patient.priorTreatments ?? []).sorted(by: { $0.createdAt > $1.createdAt })
    }
}
