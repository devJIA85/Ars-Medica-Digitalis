//
//  ClinicalDashboardView.swift
//  Ars Medica Digitalis
//
//  Dashboard clínico de lectura para Historia Clínica.
//

import SwiftUI

struct ClinicalDashboardView: View {

    let patient: Patient
    let onContact: () -> Void
    let onNewSession: () -> Void
    let onEditMedicalHistory: () -> Void
    let onShowMedicationInfo: (Medication) -> Void
    let onShowGenogram: () -> Void
    let onAddTreatment: () -> Void
    let onDeleteTreatment: (PriorTreatment) -> Void
    let onAddHospitalization: () -> Void
    let onDeleteHospitalization: (Hospitalization) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.xxl) {
                PatientSummaryCard(
                    patientName: patient.fullName,
                    age: patient.age,
                    sex: patient.biologicalSex.trimmed.isEmpty ? "No registrado" : patient.biologicalSex,
                    medicalRecordNumber: patient.medicalRecordNumber.trimmed.isEmpty ? "Sin HC" : patient.medicalRecordNumber,
                    photoData: patient.photoData,
                    firstName: patient.firstName,
                    lastName: patient.lastName,
                    genderHint: patient.gender.isEmpty ? patient.biologicalSex : patient.gender,
                    clinicalStatus: patient.clinicalStatus,
                    isContactEnabled: patient.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                    onContact: onContact,
                    onNewSession: onNewSession
                )
                PatientSummarySection(patient: patient)
                ClinicalStatusSection(patient: patient)
                MedicationSection(
                    patient: patient,
                    onEditMedicalHistory: onEditMedicalHistory,
                    onShowMedicationInfo: onShowMedicationInfo
                )
                RiskFactorsSection(
                    patient: patient,
                    onEditMedicalHistory: onEditMedicalHistory
                )
                FamilyHistorySection(
                    patient: patient,
                    onEditMedicalHistory: onEditMedicalHistory,
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
                .frame(width: 44, height: 44)
                .background(.quaternary.opacity(0.7), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
