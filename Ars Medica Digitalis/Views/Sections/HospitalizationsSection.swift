//
//  HospitalizationsSection.swift
//  Ars Medica Digitalis
//
//  Sección colapsable (TERTIARY) — collapsed por defecto.
//  "Agregar" permanece visible en el encabezado independientemente del estado.
//  Card visual delegada a ClinicalSectionCard.
//

import SwiftUI

struct HospitalizationsSection: View {

    let patient: Patient
    let onAddHospitalization: () -> Void
    let onDeleteHospitalization: (Hospitalization) -> Void

    @State private var isExpanded = false
    @State private var hospitalizationPendingDeletion: Hospitalization? = nil

    var body: some View {
        ClinicalSectionCard {
            DisclosureGroup(isExpanded: $isExpanded.animation(.easeInOut(duration: 0.2))) {
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
                                    action: { hospitalizationPendingDeletion = hospitalization }
                                )
                            }

                            if index < sortedHospitalizations.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .padding(.top, AppSpacing.sm)
            } label: {
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    Label {
                        Text("Internaciones")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "bed.double")
                            .font(.title3.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button(action: onAddHospitalization) {
                        Label("Agregar", systemImage: "plus.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Agregar internación")
                }
            }
        }
        .confirmationDialog(
            "Eliminar internación",
            isPresented: Binding(
                get: { hospitalizationPendingDeletion != nil },
                set: { if !$0 { hospitalizationPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let hospitalization = hospitalizationPendingDeletion {
                    onDeleteHospitalization(hospitalization)
                }
                hospitalizationPendingDeletion = nil
            }
            Button("Cancelar", role: .cancel) {
                hospitalizationPendingDeletion = nil
            }
        } message: {
            Text("Esta acción no se puede deshacer. El registro de la internación se eliminará definitivamente.")
        }
    }

    private var sortedHospitalizations: [Hospitalization] {
        patient.hospitalizations.sorted(by: { $0.admissionDate > $1.admissionDate })
    }
}
