//
//  ProfessionalDataSection.swift
//  Ars Medica Digitalis
//
//  Datos editables de identidad profesional.
//  El título de sección se renderiza externamente en ProfileView (small-caps "DATOS PROFESIONALES").
//
//  Layout: Grid con columna de etiquetas auto-dimensionada (Health.app pattern).
//  La columna izquierda toma el ancho de la etiqueta más larga ("Título profesional");
//  la columna derecha ocupa el espacio restante.
//

import SwiftUI
import UIKit

struct ProfessionalDataSection: View {

    @Binding var fullName: String
    @Binding var professionalTitle: String
    @Binding var licenseNumber: String
    @Binding var email: String

    var body: some View {
        CardContainer(style: .flat, usesGlassEffect: false) {
            Grid(alignment: .leading, horizontalSpacing: AppSpacing.md, verticalSpacing: 0) {

                fieldRow(
                    label: "Nombre completo",
                    text: $fullName,
                    capitalization: .words,
                    contentType: .name
                )

                Divider()

                fieldRow(
                    label: "Título profesional",
                    text: $professionalTitle,
                    capitalization: .words
                )

                Divider()

                fieldRow(
                    label: "Matrícula",
                    text: $licenseNumber,
                    capitalization: .characters,
                    keyboardType: .asciiCapable,
                    autocorrectionDisabled: true
                )

                Divider()

                fieldRow(
                    label: "Email",
                    text: $email,
                    capitalization: .never,
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    autocorrectionDisabled: true
                )
            }
        }
    }

    // MARK: - Row builder

    /// Fila etiqueta + campo de texto con alineación de columna auto-adaptable.
    ///
    /// Firma extensible: `validationState`, `helperText` y `trailingAccessory`
    /// pueden agregarse como parámetros opcionales sin romper los call sites existentes.
    private func fieldRow(
        label: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization = .sentences,
        contentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        autocorrectionDisabled: Bool = false
    ) -> some View {
        GridRow(alignment: .center) {
            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
                .padding(.vertical, 12)

            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .textInputAutocapitalization(capitalization)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .autocorrectionDisabled(autocorrectionDisabled)
                .padding(.vertical, 12)
        }
    }
}
