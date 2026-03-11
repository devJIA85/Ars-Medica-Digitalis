//
//  ProfileHeaderSection.swift
//  Ars Medica Digitalis
//
//  Panel de identidad profesional con lenguaje Liquid Glass.
//  Muestra avatar SF Symbol, nombre, título y matrícula en jerarquía tipográfica,
//  más un botón "Editar" que hace scroll hasta el formulario de datos.
//

import SwiftUI

struct ProfileHeaderSection: View {

    let fullName: String
    let professionalTitle: String
    let licenseNumber: String
    let onEdit: () -> Void

    var body: some View {
        CardContainer(style: .elevated) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                avatar
                professionalInfo
                Spacer(minLength: AppSpacing.sm)
                editButton
            }
        }
    }

    // MARK: - Subvistas

    /// Círculo translúcido con ícono SF Symbol person.crop.circle.fill centrado.
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 64, height: 64)
                .overlay(
                    // Trazo reflectante sutil que simula el brillo del cristal
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
        }
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

    /// Botón cápsula azul que desplaza la vista hasta el formulario editable.
    private var editButton: some View {
        Button(action: onEdit) {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.footnote.weight(.semibold))
                Text("Editar")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(.blue.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Editar datos profesionales")
    }
}
