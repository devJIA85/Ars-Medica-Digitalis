//
//  HospitalizationsSection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct HospitalizationsSection: View {

    let patient: Patient
    let onAddHospitalization: () -> Void
    let onDeleteHospitalization: (Hospitalization) -> Void

    var body: some View {
        CardContainer(
            title: "Internaciones",
            systemImage: "bed.double",
            style: .flat
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if sortedHospitalizations.isEmpty {
                    ClinicalEmptyState(text: "Sin internaciones previas registradas")
                } else {
                    ForEach(Array(sortedHospitalizations.enumerated()), id: \.element.id) { index, hospitalization in
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            NavigationLink {
                                HospitalizationFormView(patient: patient, hospitalization: hospitalization)
                            } label: {
                                HospitalizationTimelineRow(
                                    hospitalization: hospitalization,
                                    isFirst: index == 0,
                                    isLast: index == sortedHospitalizations.count - 1
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            ClinicalDeleteButton(
                                label: "Eliminar internación del \(hospitalization.admissionDate.esShortDateAbbrev())",
                                action: {
                                    onDeleteHospitalization(hospitalization)
                                }
                            )
                        }

                        if index < sortedHospitalizations.count - 1 {
                            Divider()
                        }
                    }
                }

                Button(action: onAddHospitalization) {
                    Label("Agregar internación", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var sortedHospitalizations: [Hospitalization] {
        (patient.hospitalizations ?? []).sorted(by: { $0.admissionDate > $1.admissionDate })
    }
}

private struct HospitalizationTimelineRow: View {

    let hospitalization: Hospitalization
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            HospitalizationTimelineIndicator(isFirst: isFirst, isLast: isLast)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(hospitalization.admissionDate.esShortDateAbbrev())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                HStack(spacing: AppSpacing.sm) {
                    Text("Internación")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    Text("Previa")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.7), in: Capsule())
                }

                if !hospitalization.durationDescription.trimmed.isEmpty {
                    Text(hospitalization.durationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !hospitalization.observations.trimmed.isEmpty {
                    Text(hospitalization.observations)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct HospitalizationTimelineIndicator: View {

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
