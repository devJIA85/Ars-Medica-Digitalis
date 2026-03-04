//
//  SessionTypeStylePicker.swift
//  Ars Medica Digitalis
//
//  Selector reutilizable para identidad visual del tipo facturable.
//

import SwiftUI

struct SessionTypeIconBadge: View {

    let symbolName: String
    let colorToken: SessionTypeColorToken
    var frameSize: CGFloat = 68
    var symbolSize: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(colorToken.softFill)
            .frame(width: frameSize, height: frameSize)
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(colorToken.color)
                    .accessibilityHidden(true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(colorToken.softStroke)
            }
    }
}

struct SessionTypeStylePicker: View {

    let previewName: String
    let previewPrice: String
    @Binding var selectedColorToken: String
    @Binding var selectedSymbolName: String

    private let symbolColumns = [
        GridItem(.adaptive(minimum: 76), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            previewCard

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Color")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                colorPalette
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("SF Symbol")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: symbolColumns, spacing: 10) {
                    ForEach(SessionTypeSymbolCatalog.options) { option in
                        symbolButton(for: option)
                    }
                }
            }
        }
    }

    private var resolvedColorToken: SessionTypeColorToken {
        SessionTypeColorToken(rawValue: selectedColorToken) ?? .blue
    }

    private var resolvedSymbolName: String {
        SessionTypeSymbolCatalog.isSupported(selectedSymbolName)
        ? selectedSymbolName
        : SessionTypeSymbolCatalog.defaultSymbolName
    }

    private var previewCard: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            SessionTypeIconBadge(
                symbolName: resolvedSymbolName,
                colorToken: resolvedColorToken,
                frameSize: 60,
                symbolSize: 24
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(previewName.isEmpty ? "Nuevo tipo" : previewName)
                    .font(.headline)

                Text(previewPrice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var colorPalette: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(SessionTypeColorToken.allCases) { token in
                Button {
                    selectedColorToken = token.rawValue
                } label: {
                    Circle()
                        .fill(token.color.gradient)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.8), lineWidth: token == resolvedColorToken ? 3 : 0)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(.black.opacity(0.10))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(token.title)
            }
        }
    }

    private func symbolButton(for option: SessionTypeSymbolOption) -> some View {
        let isSelected = option.systemName == resolvedSymbolName

        return Button {
            selectedSymbolName = option.systemName
        } label: {
            VStack(spacing: 8) {
                Image(systemName: option.systemName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? resolvedColorToken.color : .secondary)

                Text(option.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 68)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? resolvedColorToken.softFill : Color(.secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? resolvedColorToken.softStroke : Color.primary.opacity(0.06))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
    }
}

#Preview {
    @Previewable @State var color = SessionTypeColorToken.blue.rawValue
    @Previewable @State var symbol = SessionTypeSymbolCatalog.defaultSymbolName

    SessionTypeStylePicker(
        previewName: "Sesion Psi",
        previewPrice: "ARS 55.000,00",
        selectedColorToken: $color,
        selectedSymbolName: $symbol
    )
    .padding()
}
