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
            // MARK: - Header visual con avatar del profesional

            Section {
                HStack(spacing: 16) {
                    // Avatar circular con iniciales o ícono por defecto
                    ZStack {
                        Circle()
                            .fill(.tint.opacity(0.12))
                            .frame(width: 64, height: 64)

                        if let initials = professionalInitials {
                            Text(initials)
                                .font(.title2.bold())
                                .foregroundStyle(.tint)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.tint)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.fullName.isEmpty ? "Sin nombre" : viewModel.fullName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if !viewModel.specialty.isEmpty {
                            Text(viewModel.specialty)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: - Dashboard de Estadísticas

            Section {
                NavigationLink {
                    DashboardView(professional: professional)
                } label: {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }
            } header: {
                Label("Estadísticas", systemImage: "chart.pie")
            }

            // MARK: - Datos Profesionales

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    TextField("Nombre completo", text: $viewModel.fullName)
                        .textContentType(.name)
                }

                HStack(spacing: 12) {
                    Image(systemName: "stethoscope")
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    TextField("Especialidad", text: $viewModel.specialty)
                }

                HStack(spacing: 12) {
                    Image(systemName: "number")
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    TextField("Número de matrícula", text: $viewModel.licenseNumber)
                }
            } header: {
                Label("Datos Profesionales", systemImage: "person.text.rectangle")
            }

            // MARK: - Contacto

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            } header: {
                Label("Contacto", systemImage: "phone.circle")
            }

            // MARK: - Información de trazabilidad

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    LabeledContent("Creado", value: professional.createdAt.formatted(date: .abbreviated, time: .omitted))
                }

                HStack(spacing: 12) {
                    Image(systemName: "pencil.and.outline")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    LabeledContent("Modificado", value: professional.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                Label("Información", systemImage: "info.circle")
            }
        }
        .navigationTitle("Editar Perfil")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Helpers

    /// Iniciales del profesional para el avatar circular.
    /// Toma la primera letra del nombre y apellido (si hay espacio).
    private var professionalInitials: String? {
        let name = viewModel.fullName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let parts = name.split(separator: " ")
        if parts.count >= 2,
           let first = parts.first?.prefix(1),
           let last = parts.last?.prefix(1) {
            return "\(first)\(last)".uppercased()
        }
        // Solo un nombre → primera letra
        return String(name.prefix(1)).uppercased()
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
