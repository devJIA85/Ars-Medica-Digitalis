//
//  ProfessionalDataSection.swift
//  Ars Medica Digitalis
//
//  Datos editables de identidad profesional.
//

import SwiftUI

struct ProfessionalDataSection: View {

    @Binding var fullName: String
    @Binding var professionalTitle: String
    @Binding var licenseNumber: String

    var body: some View {
        SettingsSectionCard(
            title: "Datos profesionales",
            systemImage: "person.text.rectangle",
            subtitle: "Informacion visible y administrativa del profesional."
        ) {
            SettingsRow(systemImage: "person.fill", title: "Nombre completo") {
                inlineField("Nombre completo", text: $fullName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
            }

            Divider()

            SettingsRow(systemImage: "stethoscope", title: "Titulo profesional") {
                inlineField("Titulo profesional", text: $professionalTitle)
                    .textInputAutocapitalization(.words)
            }

            Divider()

            SettingsRow(systemImage: "number", title: "Matricula") {
                inlineField("Numero de matricula", text: $licenseNumber)
                    .textInputAutocapitalization(.characters)
            }
        }
    }

    private func inlineField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(.body)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 220, alignment: .trailing)
    }
}
