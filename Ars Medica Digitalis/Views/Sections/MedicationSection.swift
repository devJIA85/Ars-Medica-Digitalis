//
//  MedicationSection.swift
//  Ars Medica Digitalis
//
//  Hierarchy:
//    title3.semibold  → "Medicación" (SectionCard header)
//    body.semibold    → principio activo (primary row text)
//    subheadline/secondary  → nombre comercial
//    subheadline/secondary  → "Observaciones" label
//    subheadline/tertiary   → Observaciones content (clearly subordinate)
//
//  [+] action in header is always visible regardless of list state.
//

import SwiftUI

struct MedicationSection: View {

    let patient: Patient
    let onEditMedicalHistory: () -> Void
    let onShowMedicationInfo: (Medication) -> Void

    var body: some View {
        SectionCard(title: "Medicación", icon: "pills") {
            Button(action: onEditMedicalHistory) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Agregar medicación")
        } content: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if sortedCurrentMedications.isEmpty {
                    if patient.currentMedication.trimmed.isEmpty {
                        EmptyStateView(
                            message: "Sin medicación registrada",
                            buttonTitle: "Agregar medicación",
                            action: onEditMedicalHistory
                        )
                    } else {
                        legacyTextBlock(patient.currentMedication)
                    }
                } else {
                    ForEach(sortedCurrentMedications) { medication in
                        MedicationRow(
                            medication: medication,
                            onTap: { onShowMedicationInfo(medication) },
                            onDelete: { deleteMedication(medication) },
                            onEdit: onEditMedicalHistory
                        )

                        if medication.id != sortedCurrentMedications.last?.id {
                            Divider()
                                .opacity(0.3)
                        }
                    }

                    if !patient.currentMedication.trimmed.isEmpty {
                        Divider()
                            .padding(.vertical, AppSpacing.xs)

                        Text("Observaciones")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(patient.currentMedication.trimmed)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func legacyTextBlock(_ text: String) -> some View {
        Text(text.trimmed)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture { onEditMedicalHistory() }
    }

    // MARK: - Data

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

// MARK: - Medication Row

private struct MedicationRow: View {

    let medication: Medication
    let onTap: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "pills")
                    .font(.system(size: 17, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(medication.primaryDisplayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(medication.secondaryDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(medication.primaryDisplayName)
        .accessibilityValue(medication.secondaryDisplayName)
        .accessibilityHint("Abre el detalle de esta medicación")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Eliminar", role: .destructive, action: onDelete)
            Button("Editar", action: onEdit).tint(.blue)
        }
    }
}
