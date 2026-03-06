//
//  ProfileSettingsView.swift
//  Ars Medica Digitalis
//
//  Pantalla dedicada para ajustes de privacidad, apariencia y metadatos.
//

import SwiftUI

struct ProfileSettingsView: View {

    let professional: Professional

    @AppStorage("security.biometricEnabled") private var biometricLockEnabled: Bool = false
    @AppStorage("appearance.themeColor") private var themeColorRaw: String = AppThemeColor.blue.rawValue

    @State private var biometricCapability = BiometricCapability(
        kind: .none,
        isAvailable: false,
        unavailableReason: nil
    )

    private let biometricAuthService = BiometricAuthService()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sectionGap) {
                SettingsSectionCard(
                    title: "Ajustes",
                    systemImage: "gearshape",
                    subtitle: "Privacidad, aspecto visual e informacion del perfil."
                ) {
                    ToggleRow(
                        systemImage: biometricSystemImage,
                        title: "Bloqueo biometrico",
                        subtitle: biometricCapability.isAvailable
                            ? biometricCapability.localizedName
                            : "No disponible",
                        isEnabled: biometricCapability.isAvailable,
                        isOn: $biometricLockEnabled
                    )

                    Divider()

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsRow(
                            systemImage: "paintbrush",
                            title: "Apariencia",
                            subtitle: themeColorDisplayName
                        ) {
                            settingsChevron
                        }
                    }
                    .buttonStyle(.plain)

                    Divider()

                    MetadataRow(
                        title: "Creado",
                        value: professional.createdAt.esShortDate(),
                        systemImage: "calendar.badge.clock"
                    )

                    Divider()

                    MetadataRow(
                        title: "Ultima modificacion",
                        value: professional.updatedAt.esShortDateTime(),
                        systemImage: "pencil.and.outline"
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .themedBackground()
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: professional.updatedAt) {
            await loadBiometricCapability()
        }
    }

    @MainActor
    private func loadBiometricCapability() async {
        biometricCapability = biometricAuthService.capability()

        if biometricLockEnabled && !biometricCapability.isAvailable {
            biometricLockEnabled = false
        }
    }

    private var themeColorDisplayName: String {
        (AppThemeColor(rawValue: themeColorRaw) ?? .blue).displayName
    }

    private var biometricSystemImage: String {
        switch biometricCapability.kind {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .none: "lock.shield"
        }
    }

    private var settingsChevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
