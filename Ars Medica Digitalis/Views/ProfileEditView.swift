//
//  ProfileEditView.swift
//  Ars Medica Digitalis
//
//  Edición del perfil profesional existente (HU-01, criterio de aceptación 2).
//  Los cambios se reflejan en todos los dispositivos vía CloudKit.
//

import SwiftUI
import SwiftData

struct ProfileEditView: View {

    @Environment(\.dismiss) private var dismiss

    let professional: Professional

    @Bindable var viewModel = ProfessionalViewModel()

    var body: some View {
        Form {
            Section("Datos Profesionales") {
                TextField("Nombre completo", text: $viewModel.fullName)
                    .textContentType(.name)

                TextField("Especialidad", text: $viewModel.specialty)

                TextField("Número de matrícula", text: $viewModel.licenseNumber)
            }

            Section("Contacto") {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }

            Section("Información") {
                LabeledContent("Creado", value: professional.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Última modificación", value: professional.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .navigationTitle("Editar Perfil")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    viewModel.update(professional)
                    dismiss()
                }
                .disabled(!viewModel.canSave)
            }
        }
        .onAppear {
            viewModel.load(from: professional)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileEditView(
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
