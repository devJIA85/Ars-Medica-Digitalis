//
//  PrivacySection.swift
//  Ars Medica Digitalis
//
//  Configuracion de privacidad del perfil profesional.
//

import SwiftUI

struct PrivacySection: View {

    @Binding var biometricLockEnabled: Bool
    let capability: BiometricCapability

    var body: some View {
        SettingsSectionCard(
            title: "Privacidad",
            systemImage: "lock.shield",
            subtitle: L10n.tr("settings.privacy.subtitle")
        ) {
            ToggleRow(
                systemImage: biometricSystemImage,
                title: "Bloqueo al abrir la app",
                subtitle: capability.isAvailable ? capability.localizedName : "Biometria no disponible",
                isEnabled: capability.isAvailable,
                isOn: $biometricLockEnabled
            )

            Divider()

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(statusMessage)
        }
    }

    private var biometricSystemImage: String {
        switch capability.kind {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .none: "lock.shield"
        }
    }

    private var statusMessage: String {
        if capability.isAvailable {
            return "Este dispositivo puede proteger la app con \(capability.localizedName)."
        }

        return capability.unavailableReason ?? "La autenticacion biometrica no esta disponible."
    }
}
