//
//  SettingsRow.swift
//  Ars Medica Digitalis
//
//  Fila reutilizable para configuraciones y accesos rapidos del perfil.
//

import SwiftUI

struct SettingsRow<Accessory: View>: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .accentColor
    @ViewBuilder var accessory: Accessory

    init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        tint: Color = .accentColor,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.accessory = accessory()
    }

    init(
        systemImage: String,
        title: String,
        subtitle: String? = nil,
        tint: Color = .accentColor
    ) where Accessory == EmptyView {
        self.init(systemImage: systemImage, title: title, subtitle: subtitle, tint: tint) {
            EmptyView()
        }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    rowLabel
                    accessory
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    rowLabel
                    Spacer(minLength: AppSpacing.md)
                    accessory
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var rowLabel: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.thinMaterial)
            .frame(width: 36, height: 36)
            .overlay {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.18))
            }
    }
}

#Preview {
    SettingsSectionCard(title: "Vista previa", systemImage: "slider.horizontal.3") {
        SettingsRow(systemImage: "person.fill", title: "Nombre completo", subtitle: "Visible para el profesional") {
            Text("Juan I. Antolini")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
