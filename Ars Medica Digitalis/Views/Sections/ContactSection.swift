//
//  ContactSection.swift
//  Ars Medica Digitalis
//
//  Informacion de contacto extensible del profesional.
//

import SwiftUI

struct ContactSection: View {

    @Binding var email: String

    var body: some View {
        SettingsSectionCard(
            title: "Contacto",
            systemImage: "envelope.badge",
            subtitle: "Preparado para sumar telefono y sitio web en futuras iteraciones."
        ) {
            SettingsRow(systemImage: "envelope.fill", title: "Email") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 240, alignment: .trailing)
            }
        }
    }
}
