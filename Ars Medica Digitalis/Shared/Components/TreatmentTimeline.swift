//
//  TreatmentTimeline.swift
//  Ars Medica Digitalis
//
//  Timeline de tratamientos previos con navegación al detalle.
//

import SwiftUI

struct TreatmentTimeline<Destination: View>: View {

    let treatments: [PriorTreatment]
    let destination: (PriorTreatment) -> Destination
    let onDelete: (PriorTreatment) -> Void

    @State private var visibleTreatmentIDs: Set<PriorTreatment.ID> = []
    @State private var treatmentPendingDeletion: PriorTreatment? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(treatments.enumerated()), id: \.element.id) { index, treatment in
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    NavigationLink {
                        destination(treatment)
                    } label: {
                        TimelineRow(
                            dateLabel: yearLabel(for: treatment),
                            title: treatmentTypeLabel(for: treatment),
                            subtitle: treatment.durationDescription.trimmed.isEmpty ? nil : treatment.durationDescription,
                            statusLabel: outcomeLabel(for: treatment),
                            statusVariant: outcomeVariant(for: treatment),
                            isFirst: index == 0,
                            isLast: index == treatments.count - 1,
                            showsChevron: true,
                            notes: treatment.observations.trimmed.isEmpty ? nil : treatment.observations
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    ClinicalDeleteButton(
                        label: "Eliminar tratamiento \(treatmentTypeLabel(for: treatment))",
                        action: {
                            treatmentPendingDeletion = treatment
                        }
                    )
                }
                .opacity(visibleTreatmentIDs.contains(treatment.id) ? 1 : 0)
                .offset(y: visibleTreatmentIDs.contains(treatment.id) ? 0 : 12)
                .onAppear {
                    showTreatmentIfNeeded(treatment.id, delay: Double(index) * 0.08)
                }

                if index < treatments.count - 1 {
                    Divider()
                }
            }
        }
        .confirmationDialog(
            "Eliminar tratamiento",
            isPresented: Binding(
                get: { treatmentPendingDeletion != nil },
                set: { if !$0 { treatmentPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let treatment = treatmentPendingDeletion {
                    onDelete(treatment)
                }
                treatmentPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) {
                treatmentPendingDeletion = nil
            }
        } message: {
            Text("Esta acción no se puede deshacer. El registro del tratamiento se eliminará definitivamente.")
        }
    }

    private func showTreatmentIfNeeded(_ treatmentID: PriorTreatment.ID, delay: Double) {
        guard visibleTreatmentIDs.contains(treatmentID) == false else { return }

        Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }

            _ = withAnimation(.easeOut(duration: 0.4)) {
                visibleTreatmentIDs.insert(treatmentID)
            }
        }
    }

    private func yearLabel(for treatment: PriorTreatment) -> String {
        treatment.createdAt.formatted(.dateTime.year())
    }

    private func treatmentTypeLabel(for treatment: PriorTreatment) -> String {
        switch treatment.treatmentType {
        case "psicoterapia":
            return "Psicoterapia"
        case "psiquiatría":
            return "Psiquiatría"
        case "otro":
            return "Otro tratamiento"
        default:
            return treatment.treatmentType.capitalized
        }
    }

    private func outcomeLabel(for treatment: PriorTreatment) -> String {
        switch treatment.outcome {
        case "alta":
            return "Alta"
        case "abandono":
            return "Abandono"
        case "derivación":
            return "Derivación"
        case "en curso":
            return "En curso"
        default:
            return treatment.outcome.trimmed.isEmpty ? "Registrado" : treatment.outcome.capitalized
        }
    }

    private func outcomeVariant(for treatment: PriorTreatment) -> StatusBadge.Variant {
        switch treatment.outcome {
        case "alta":
            return .success
        case "abandono":
            return .warning
        case "derivación":
            return .custom(.blue)
        case "en curso":
            return .custom(.indigo)
        default:
            return .neutral
        }
    }
}
