//
//  ClinicalDashboardView.swift
//  Ars Medica Digitalis
//
//  Dashboard clínico de lectura para Historia Clínica.
//

import SwiftUI

struct ClinicalDashboardView: View {

    let patient: Patient
    let onShowMedicationInfo: (Medication) -> Void
    let onShowGenogram: () -> Void
    let onAddTreatment: () -> Void
    let onDeleteTreatment: (PriorTreatment) -> Void
    let onAddHospitalization: () -> Void
    let onDeleteHospitalization: (Hospitalization) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.xxl) {
                PatientSummarySection(patient: patient)
                ClinicalStatusSection(patient: patient)
                MedicationSection(
                    patient: patient,
                    onShowMedicationInfo: onShowMedicationInfo
                )
                RiskFactorsSection(patient: patient)
                FamilyHistorySection(
                    patient: patient,
                    onShowGenogram: onShowGenogram
                )
                TreatmentsSection(
                    patient: patient,
                    onAddTreatment: onAddTreatment,
                    onDeleteTreatment: onDeleteTreatment
                )
                HospitalizationsSection(
                    patient: patient,
                    onAddHospitalization: onAddHospitalization,
                    onDeleteHospitalization: onDeleteHospitalization
                )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            .backgroundExtensionEffect()
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct ClinicalMetricTile: View {

    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
    }
}

struct ClinicalEmptyState: View {

    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ClinicalDeleteButton: View {

    let label: String
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .font(.footnote.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(.quaternary.opacity(0.7), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
