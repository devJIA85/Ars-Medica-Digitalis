//
//  MetadataRow.swift
//  Ars Medica Digitalis
//
//  Fila compacta para metadatos de solo lectura.
//

import SwiftUI

struct MetadataRow: View, Equatable {

    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.md)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 44, alignment: .leading)
    }
}

#Preview {
    MetadataRow(
        title: "Ultima modificacion",
        value: "04 Mar 2026 14:12",
        systemImage: "pencil.and.outline"
    )
    .padding()
}
