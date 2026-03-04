//
//  PatientSummaryCard.swift
//  Ars Medica Digitalis
//
//  Tarjeta resumida del paciente para el encabezado del dashboard clínico.
//

import SwiftUI

struct PatientSummaryCard: View {

    let patientName: String
    let age: Int
    let sex: String
    let medicalRecordNumber: String
    let photoData: Data?
    let firstName: String
    let lastName: String
    let genderHint: String
    let clinicalStatus: String
    var isContactEnabled: Bool = true
    let onContact: () -> Void
    let onNewSession: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var avatarSize: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            headerContent
            actionsContent
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    @ViewBuilder
    private var headerContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                avatarView
                identityContent
            }
        } else {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                avatarView
                identityContent
                Spacer(minLength: 0)
            }
        }
    }

    private var avatarView: some View {
        PatientAvatarView(
            photoData: photoData,
            firstName: firstName,
            lastName: lastName,
            genderHint: genderHint,
            clinicalStatus: clinicalStatus,
            size: avatarSize
        )
        .accessibilityHidden(true)
    }

    private var identityContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(patientName)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text("\(age) • \(sex)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(medicalRecordNumber)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(patientName), \(age) años, \(sex), historia clínica \(medicalRecordNumber)")
    }

    private var actionsContent: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: AppSpacing.sm) {
                contactButton
                newSessionButton
            }

            VStack(spacing: AppSpacing.sm) {
                contactButton
                newSessionButton
            }
        }
    }

    private var contactButton: some View {
        Button(action: onContact) {
            Label("Contact", systemImage: "phone.fill")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(!isContactEnabled)
        .accessibilityLabel("Contactar paciente")
        .accessibilityHint(isContactEnabled ? "Inicia una llamada al paciente" : "No hay teléfono registrado")
    }

    private var newSessionButton: some View {
        Button(action: onNewSession) {
            Label("New Session", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel("Nueva sesión")
        .accessibilityHint("Abre el formulario para registrar una nueva sesión")
    }
}
