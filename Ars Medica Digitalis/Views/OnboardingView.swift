//
//  OnboardingView.swift
//  Ars Medica Digitalis
//
//  Pantalla de registro inicial del profesional (HU-01).
//  Se muestra únicamente cuando no existe un Professional en SwiftData.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {

    @Environment(\.modelContext) private var modelContext

    @Bindable var viewModel = ProfessionalViewModel()

    // Callback para notificar a ContentView que el registro se completó
    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    headerView
                }
                .listRowBackground(Color.clear)

                Section("Datos Profesionales") {
                    TextField("Nombre completo", text: $viewModel.fullName)
                        .textContentType(.name)

                    TextField("Especialidad", text: $viewModel.specialty)

                    TextField("Número de matrícula", text: $viewModel.licenseNumber)
                }

                Section("Contacto (opcional)") {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section {
                    Button(action: save) {
                        Text("Crear Perfil")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .navigationTitle("Bienvenido")
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "stethoscope")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Ars Medica Digitalis")
                .font(.title2)
                .fontWeight(.bold)

            Text("Configurá tu perfil profesional para comenzar a gestionar historias clínicas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    // MARK: - Acciones

    private func save() {
        viewModel.createProfessional(in: modelContext)
        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: Professional.self, inMemory: true)
}
