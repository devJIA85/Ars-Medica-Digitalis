//
//  RichTextClinicalEditor.swift
//  Ars Medica Digitalis
//
//  Editor clínico enriquecido reutilizable para iOS 26.
//  Implementado 100% en SwiftUI con AttributedString + AttributedTextSelection.
//

import SwiftUI

private extension AttributedString {
    /// Representación plana para placeholders y validaciones de texto vacío.
    var plainText: String {
        String(characters)
    }
}

private extension String {
    /// Remueve una viñeta líder simple para permitir toggle de listas.
    func removingLeadingBullet() -> String {
        if hasPrefix("• ") {
            return String(dropFirst(2))
        }

        if hasPrefix("•") {
            return String(dropFirst())
        }

        return self
    }
}

struct RichTextClinicalEditor: View {

    let title: String
    let placeholder: String
    @Binding var text: AttributedString
    /// Locale clínico por defecto para privilegiar español en edición.
    private let editorLocale = Locale(identifier: "es_AR")

    /// La selección se mantiene local al componente para que cada editor
    /// (Notas y Plan) tenga su propio contexto de formato sin interferencias.
    @State private var selection = AttributedTextSelection()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                formattingToolbar

                ZStack(alignment: .topLeading) {
                    if text.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }

                    // TextEditor rico de iOS 26: texto + selección atribuida.
                    TextEditor(text: $text, selection: $selection)
                        .font(.body)
                        .lineHeight(.leading(increase: 4))
                        // Fuerza contexto regional en español para que el sistema
                        // no priorice heurísticas de autocorrección en inglés.
                        .environment(\.locale, editorLocale)
                        .textInputAutocapitalization(.sentences)
                        // Desactivamos autocorrección para evitar reemplazos
                        // agresivos en idioma incorrecto durante redacción clínica.
                        .autocorrectionDisabled(true)
                        .textEditorStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 170)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    /// Toolbar de formato de alto impacto clínico.
    /// Se priorizan acciones frecuentes en documentación longitudinal.
    private var formattingToolbar: some View {
        HStack(spacing: AppSpacing.sm) {
            toolbarButton("B", accessibilityLabel: "Negrita", action: applyBold)
            toolbarButton("I", accessibilityLabel: "Cursiva", font: .body.italic(), action: applyItalic)
            toolbarButton("U", accessibilityLabel: "Subrayado", action: toggleUnderline)
            toolbarButton("S", accessibilityLabel: "Tachado", action: toggleStrikethrough)
            toolbarButton("•", accessibilityLabel: "Lista con viñetas", action: toggleBulletList)
            toolbarButton("H", accessibilityLabel: "Encabezado", action: applyHeading)
            Spacer(minLength: 0)
        }
    }

    /// Botón compacto de toolbar con affordance consistente.
    @ViewBuilder
    private func toolbarButton(
        _ title: String,
        accessibilityLabel: String,
        font: Font = .body.weight(.semibold),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .frame(width: 32, height: 32)
                .foregroundStyle(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Aplica negrita al rango seleccionado, o al typing style si hay cursor.
    private func applyBold() {
        text.transformAttributes(in: &selection) {
            let font = $0.font ?? .body
            $0.font = font.bold()
        }
    }

    /// Aplica cursiva al rango seleccionado.
    private func applyItalic() {
        text.transformAttributes(in: &selection) {
            let font = $0.font ?? .body
            $0.font = font.italic()
        }
    }

    /// Toggle de subrayado para selección actual.
    private func toggleUnderline() {
        text.transformAttributes(in: &selection) {
            $0.underlineStyle = $0.underlineStyle == .single ? nil : .single
        }
    }

    /// Toggle de tachado para selección actual.
    private func toggleStrikethrough() {
        text.transformAttributes(in: &selection) {
            $0.strikethroughStyle = $0.strikethroughStyle == .single ? nil : .single
        }
    }

    /// Marca el contenido seleccionado como encabezado para destacar hitos clínicos.
    private func applyHeading() {
        text.transformAttributes(in: &selection) {
            $0.font = .title3.weight(.semibold)
        }
    }

    /// Inserta o remueve viñetas sobre la selección. Si hay solo cursor,
    /// inserta una viñeta nueva para acelerar la redacción de planes.
    private func toggleBulletList() {
        switch selection.indices(in: text) {
        case .insertionPoint:
            text.replaceSelection(&selection, withCharacters: "• ")

        case .ranges:
            let selectedText = String(text[selection].characters)
            let lines = selectedText
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)

            let hasContent = lines.contains { !$0.isEmpty }
            let removeBullets = hasContent && lines.allSatisfy { line in
                line.isEmpty || line.hasPrefix("•")
            }

            let transformedLines = lines.map { line in
                guard !line.isEmpty else { return line }
                return removeBullets ? line.removingLeadingBullet() : "• \(line)"
            }

            text.replaceSelection(
                &selection,
                withCharacters: transformedLines.joined(separator: "\n")
            )
        }
    }
}

#Preview("RichTextClinicalEditor") {
    @Previewable @State var notes = AttributedString("Paciente refiere mejoría parcial de síntomas.")

    return RichTextClinicalEditor(
        title: "Notas clínicas",
        placeholder: "Escribí las notas de la sesión...",
        text: $notes
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
