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
        SectionCard(
            title: "Internaciones",
            icon: "bed.double",
            action: {
                Button(action: onAddHospitalization) {
                    Label("Agregar", systemImage: "plus.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agregar internación")
            }
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if sortedHospitalizations.isEmpty {
                    EmptyStateView(
                        message: "Sin internaciones registradas",
                        buttonTitle: "Agregar internación",
                        action: onAddHospitalization
                    )
                } else {
                    ForEach(Array(sortedHospitalizations.enumerated()), id: \.element.id) { index, hospitalization in
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            NavigationLink {
                                HospitalizationFormView(patient: patient, hospitalization: hospitalization)
                            } label: {
                                TimelineRow(
                                    dateLabel: hospitalization.admissionDate.esShortDateAbbrev(),
                                    title: "Internación",
                                    subtitle: hospitalization.durationDescription.trimmed.isEmpty ? nil : hospitalization.durationDescription,
                                    statusLabel: "Previa",
                                    statusVariant: .neutral,
                                    isFirst: index == 0,
                                    isLast: index == sortedHospitalizations.count - 1,
                                    showsChevron: true,
                                    notes: hospitalization.observations.trimmed.isEmpty ? nil : hospitalization.observations
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
            }
        }
    }

    private var sortedHospitalizations: [Hospitalization] {
        (patient.hospitalizations ?? []).sorted(by: { $0.admissionDate > $1.admissionDate })
    }
}
