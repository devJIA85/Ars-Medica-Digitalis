//
//  MMSEItemView.swift
//  Ars Medica Digitalis
//
//  Render dinámico de ítems MMSE según su tipo en el JSON.
//

import SwiftUI

struct MMSEItemView: View {
    let item: MMSEItem
    let response: Bool?
    let onSelectResponse: @MainActor (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            switch item.type {
            case .instruction:
                instructionContent
            case .boolean:
                scoredBooleanContent
            case .drawing:
                drawingContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Card informativa para instrucciones sin puntaje.
    /// Se separa visualmente para indicar que guía la administración clínica.
    private var instructionContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label("Instrucción", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(item.text ?? item.displayTitle)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    /// UI para ítems booleanos con dos acciones mutuamente excluyentes.
    private var scoredBooleanContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(item.displayTitle)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            responseButtons
        }
    }

    /// UI específica para dibujo: instrucción + placeholder visual + scoring booleano.
    private var drawingContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(item.displayTitle)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let text = item.text {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .stroke(
                    Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
                .frame(minHeight: 120)
                .overlay {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "pencil.and.outline")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Área de evaluación gráfica")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(AppSpacing.md)
                }
                .accessibilityHidden(true)

            Text("Evaluar si el paciente copia correctamente los pentágonos intersectados")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            responseButtons
        }
    }

    /// Botones reutilizables para respuestas correctas/incorrectas.
    /// Se usan estilos con alto contraste y targets de al menos 44 pt.
    private var responseButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            responseButton(
                title: "Correcto",
                systemImage: "checkmark.circle.fill",
                value: true,
                tint: .green
            )

            responseButton(
                title: "Incorrecto",
                systemImage: "xmark.circle.fill",
                value: false,
                tint: .red
            )
        }
    }

    private func responseButton(
        title: String,
        systemImage: String,
        value: Bool,
        tint: Color
    ) -> some View {
        let isSelected = response == value

        return Button {
            onSelectResponse(value)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, AppSpacing.sm)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? tint : .primary)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(
                    isSelected
                    ? tint.opacity(0.18)
                    : Color(uiColor: .tertiarySystemGroupedBackground)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.45) : .clear, lineWidth: 1)
        )
        .accessibilityLabel("\(item.displayTitle). \(title)")
        .accessibilityHint("Marca la respuesta como \(title.lowercased())")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
