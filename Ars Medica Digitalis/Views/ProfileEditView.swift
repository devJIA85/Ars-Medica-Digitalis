//
//  ProfileEditView.swift
//  Ars Medica Digitalis
//
//  Edición del perfil profesional existente (HU-01, criterio de aceptación 2).
//  Los cambios se reflejan en todos los dispositivos vía CloudKit.
//

import SwiftUI
import SwiftData

@available(*, deprecated, message: "Use ProfileView instead.")
struct ProfileEditView: View {
    let professional: Professional

    var body: some View {
        ProfileView(professional: professional)
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            professional: Professional(
                fullName: "Dr. Juan Pérez",
                licenseNumber: "MN 12345",
                specialty: "Psicología",
                email: "juan@example.com"
            )
        )
    }
    .modelContainer(for: Professional.self, inMemory: true)
}
