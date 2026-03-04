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
        CardContainer(
            title: "Tratamientos",
            systemImage: "cross.case",
            style: .flat
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if sortedTreatments.isEmpty {
                    ClinicalEmptyState(text: "Sin tratamientos previos registrados")
                } else {
                    ForEach(Array(sortedTreatments.enumerated()), id: \.element.id) { index, treatment in
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            NavigationLink {
                                PriorTreatmentFormView(patient: patient, treatment: treatment)
                            } label: {
                                TreatmentTimelineRow(
                                    treatment: treatment,
                                    isFirst: index == 0,
                                    isLast: index == sortedTreatments.count - 1
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            ClinicalDeleteButton(
                                label: "Eliminar tratamiento \(treatmentTypeLabel(for: treatment))",
                                action: {
                                    onDeleteTreatment(treatment)
                                }
                            )
                        }

                        if index < sortedTreatments.count - 1 {
                            Divider()
                        }
                    }
                }

                Button(action: onAddTreatment) {
                    Label("Agregar tratamiento", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var sortedTreatments: [PriorTreatment] {
        (patient.priorTreatments ?? []).sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func treatmentTypeLabel(for treatment: PriorTreatment) -> String {
        switch treatment.treatmentType {
        case "psicoterapia":
            return "Psicoterapia"
        case "psiquiatría":
            return "Psiquiatría"
        case "otro":
            return "Otro"
        default:
            return treatment.treatmentType.capitalized
        }
    }
}

private struct TreatmentTimelineRow: View {

    let treatment: PriorTreatment
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            TreatmentTimelineIndicator(isFirst: isFirst, isLast: isLast)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(treatment.createdAt.esShortDateAbbrev())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(treatmentTypeLabel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: AppSpacing.sm) {
                    if !treatment.durationDescription.trimmed.isEmpty {
                        Text(treatment.durationDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text(outcomeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(outcomeTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(outcomeTint.opacity(0.14), in: Capsule())
                }

                if !treatment.observations.trimmed.isEmpty {
                    Text(treatment.observations)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var treatmentTypeLabel: String {
        switch treatment.treatmentType {
        case "psicoterapia":
            return "Psicoterapia"
        case "psiquiatría":
            return "Psiquiatría"
        case "otro":
            return "Otro"
        default:
            return treatment.treatmentType.capitalized
        }
    }

    private var outcomeLabel: String {
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

    private var outcomeTint: Color {
        switch treatment.outcome {
        case "alta":
            return .green
        case "abandono":
            return .orange
        case "derivación":
            return .blue
        case "en curso":
            return .indigo
        default:
            return .secondary
        }
    }
}

private struct TreatmentTimelineIndicator: View {

    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.quaternary)
                .frame(width: 2, height: isFirst ? 0 : 10)
                .opacity(isFirst ? 0 : 1)

            Circle()
                .fill(.secondary.opacity(0.7))
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(.quaternary)
                .frame(width: 2)
                .frame(minHeight: isLast ? 0 : 24, maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 12)
    }
}
