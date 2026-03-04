//
//  ProfileHeaderCard.swift
//  Ars Medica Digitalis
//
//  Card principal de identidad profesional para el dashboard de perfil.
//

import SwiftUI

struct ProfileHeaderCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let initials: String?
    let fullName: String
    let professionalTitle: String
    let onEdit: () -> Void

    var body: some View {
        CardContainer(style: .elevated) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        headerIdentity
                        editButton
                    }
                } else {
                    HStack(alignment: .center, spacing: AppSpacing.md) {
                        headerIdentity
                        Spacer(minLength: AppSpacing.md)
                        editButton
                    }
                }
            }
        }
        .glassCardEntrance()
        .accessibilityElement(children: .contain)
    }

    private var headerIdentity: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            avatar

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(fullName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(professionalTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var avatar: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.thinMaterial)
            .frame(width: 84, height: 84)
            .overlay {
                Group {
                    if let initials, initials.isEmpty == false {
                        Text(initials)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.tint)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.18))
            }
            .accessibilityLabel("Avatar profesional")
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Label("Editar", systemImage: "pencil")
                .font(.body.weight(.semibold))
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Editar identidad profesional")
    }
}

#Preview {
    ProfileHeaderCard(
        initials: "JA",
        fullName: "Juan I. Antolini",
        professionalTitle: "Licenciado en Psicologia",
        onEdit: {}
    )
    .padding()
}
