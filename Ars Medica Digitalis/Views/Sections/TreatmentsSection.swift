//
//  TreatmentsSection.swift
//  Ars Medica Digitalis
//
//  Sección colapsable (TERTIARY) — collapsed por defecto.
//  "Agregar" permanece visible en el encabezado independientemente del estado.
//  Card visual delegada a ClinicalSectionCard.
//

import SwiftUI

struct TreatmentsSection: View {

    let patient: Patient
    let onAddTreatment: () -> Void
    let onDeleteTreatment: (PriorTreatment) -> Void

    @State private var isExpanded = false

    var body: some View {
        ClinicalSectionCard {
            DisclosureGroup(isExpanded: $isExpanded.animation(.easeInOut(duration: 0.2))) {
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
                .padding(.top, AppSpacing.sm)
            } label: {
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    Label {
                        Text("Tratamientos")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "cross.case")
                            .font(.title3.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button(action: onAddTreatment) {
                        Label("Agregar", systemImage: "plus.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Agregar tratamiento")
                }
            }
        }
    }

    private var sortedTreatments: [PriorTreatment] {
        patient.activePriorTreatments.sorted(by: { $0.createdAt > $1.createdAt })
    }
}
