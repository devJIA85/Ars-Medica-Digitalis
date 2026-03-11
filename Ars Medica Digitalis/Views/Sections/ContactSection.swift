//
//  ContactSection.swift
//  Ars Medica Digitalis
//
//  Informacion de contacto extensible del profesional.
//  El título de sección se renderiza externamente en ProfileView (small-caps "CONTACTO").
//

import SwiftUI

struct ContactSection: View {

    @Binding var email: String

    var body: some View {
        CardContainer(style: .flat, usesGlassEffect: false) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                Image(systemName: "envelope.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
        }
    }
}
