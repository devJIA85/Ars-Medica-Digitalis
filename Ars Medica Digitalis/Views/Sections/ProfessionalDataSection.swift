//
//  ProfessionalDataSection.swift
//  Ars Medica Digitalis
//
//  Datos editables de identidad profesional.
//  El título de sección se renderiza externamente en ProfileView (small-caps "DATOS PROFESIONALES").
//

import SwiftUI
import UIKit

struct ProfessionalDataSection: View {

    @Binding var fullName: String
    @Binding var professionalTitle: String
    @Binding var licenseNumber: String

    var body: some View {
        CardContainer(style: .flat, usesGlassEffect: false) {
            VStack(spacing: 0) {
                labeledFieldRow(
                    icon: "person.fill",
                    title: "Nombre completo",
                    text: $fullName,
                    capitalization: .words,
                    contentType: .name
                )

                Divider()

                labeledFieldRow(
                    icon: "stethoscope",
                    title: "Título profesional",
                    text: $professionalTitle,
                    capitalization: .words
                )

                Divider()

                labeledFieldRow(
                    icon: "number",
                    title: "Matrícula",
                    text: $licenseNumber,
                    capitalization: .characters
                )
            }
        }
    }

    private func labeledFieldRow(
        icon: String,
        title: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization = .sentences,
        contentType: UITextContentType? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            TextField(title, text: text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(capitalization)
                .textContentType(contentType)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

