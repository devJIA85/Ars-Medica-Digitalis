//
//  AppearanceSettingsView.swift
//  Ars Medica Digitalis
//
//  Pantalla de configuracion de apariencia: modo de color y color de acento.
//

import SwiftUI

struct AppearanceSettingsView: View {

    @AppStorage("appearance.colorScheme") private var colorSchemePreference: String = ProfileColorSchemeOption.system.rawValue
    @AppStorage("appearance.themeColor") private var themeColorRaw: String = AppThemeColor.blue.rawValue

    private var resolvedThemeColor: AppThemeColor {
        AppThemeColor(rawValue: themeColorRaw) ?? .blue
    }

    private var colorSchemeBinding: Binding<ProfileColorSchemeOption> {
        Binding(
            get: { ProfileColorSchemeOption(rawValue: colorSchemePreference) ?? .system },
            set: { colorSchemePreference = $0.rawValue }
        )
    }

    private let columns = [
        GridItem(.adaptive(minimum: 64), spacing: AppSpacing.md)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sectionGap) {
                // Seccion 1: Modo de color (sistema/claro/oscuro)
                SettingsSectionCard(
                    title: "Modo",
                    systemImage: "circle.lefthalf.filled",
                    subtitle: "Respeta el modo del sistema o fija una preferencia local."
                ) {
                    SegmentedSelector(
                        title: "Modo",
                        options: ProfileColorSchemeOption.allCases,
                        selection: colorSchemeBinding
                    )
                }

                // Seccion 2: Color de acento
                SettingsSectionCard(
                    title: "Color de acento",
                    systemImage: "paintpalette",
                    subtitle: "Define el color principal de la interfaz."
                ) {
                    themeColorGrid
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .navigationTitle("Apariencia")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Grid de colores

    private var themeColorGrid: some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
            ForEach(AppThemeColor.allCases) { themeColor in
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        themeColorRaw = themeColor.rawValue
                    }
                } label: {
                    colorCell(for: themeColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(themeColor.displayName)
            }
        }
        .sensoryFeedback(.selection, trigger: themeColorRaw)
    }

    private func colorCell(for themeColor: AppThemeColor) -> some View {
        let isSelected = themeColor == resolvedThemeColor

        return VStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(themeColor.color.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.body.bold())
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? .white.opacity(0.8) : .black.opacity(0.10),
                            lineWidth: isSelected ? 3 : 1
                        )
                }
                .shadow(
                    color: isSelected ? themeColor.color.opacity(0.35) : .clear,
                    radius: 6,
                    y: 2
                )

            Text(themeColor.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
