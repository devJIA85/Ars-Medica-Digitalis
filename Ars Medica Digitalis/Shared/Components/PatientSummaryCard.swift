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
    let birthCountryFlag: String?
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

            HStack(spacing: 6) {
                Text("\(age) • \(sex)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let birthCountryFlag {
                    Text(birthCountryFlag)
                        .font(.subheadline)
                }
            }

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
            actionButtonContent(
                title: "Llamar",
                systemImage: "phone.fill",
                tint: .green,
                isProminent: false,
                isEnabled: isContactEnabled
            )
        }
        .buttonStyle(.plain)
        .disabled(!isContactEnabled)
        .accessibilityLabel("Contactar paciente")
        .accessibilityHint(isContactEnabled ? "Muestra opciones para llamar o copiar el número" : "No hay teléfono registrado")
    }

    private var newSessionButton: some View {
        Button(action: onNewSession) {
            actionButtonContent(
                title: "Nueva sesión",
                systemImage: "plus.circle.fill",
                tint: .accentColor,
                isProminent: true,
                isEnabled: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Nueva sesión")
        .accessibilityHint("Abre el formulario para registrar una nueva sesión")
    }

    private func actionButtonContent(
        title: String,
        systemImage: String,
        tint: Color,
        isProminent: Bool,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(isProminent ? .white.opacity(0.18) : tint.opacity(0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isProminent ? .white : tint)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isProminent ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            isProminent ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color(uiColor: .secondarySystemBackground)),
            in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
        )
        .overlay {
            if isProminent == false {
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .strokeBorder(tint.opacity(0.18), lineWidth: 1)
            }
        }
        .opacity(isEnabled ? 1 : 0.6)
    }
}
