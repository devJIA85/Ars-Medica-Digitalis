//
//  ProfileHeaderSection.swift
//  Ars Medica Digitalis
//
//  Panel de identidad profesional con lenguaje Liquid Glass.
//  Muestra el avatar del profesional (predefinido o generado con IA), nombre,
//  título y matrícula en jerarquía tipográfica, más un indicador de edición
//  sobre el avatar al tocar.
//

import SwiftUI

struct ProfileHeaderSection: View {

    let fullName: String
    let professionalTitle: String
    let licenseNumber: String
    let avatarConfiguration: AvatarConfiguration
    var generatedImage: Image? = nil
    /// Callback invocado cuando el usuario toca el avatar para cambiarlo.
    var onAvatarTap: (() -> Void)? = nil

    var body: some View {
        CardContainer(style: .elevated) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                avatarButton
                professionalInfo
            }
        }
    }

    // MARK: - Subvistas

    private var avatarButton: some View {
        Button {
            onAvatarTap?()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    configuration: avatarConfiguration,
                    size: .medium,
                    generatedImage: generatedImage
                )

                // Badge de edición — solo visible si hay callback
                if onAvatarTap != nil {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, .tint)
                        .offset(x: 4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cambiar avatar")
        .accessibilityHint("Toca para seleccionar un avatar distinto")
        .disabled(onAvatarTap == nil)
    }

    /// Nombre, título profesional y matrícula con jerarquía tipográfica estricta.
    private var professionalInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fullName.isEmpty ? "Completa tu nombre" : fullName)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(professionalTitle.isEmpty ? "Agrega tu título profesional" : professionalTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if licenseNumber.isEmpty == false {
                Text(licenseNumber)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

}
