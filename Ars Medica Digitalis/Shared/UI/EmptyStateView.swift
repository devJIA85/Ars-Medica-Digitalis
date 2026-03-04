//
//  EmptyStateView.swift
//  Ars Medica Digitalis
//
//  Estado vacío reutilizable para secciones del dashboard clínico.
//

import SwiftUI

struct EmptyStateView: View {

    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Activa la acción principal de esta sección")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
    }
}
