//
//  AvatarSelectorView.swift
//  Ars Medica Digitalis
//
//  Hoja de selección de avatar: cuadrícula de estilos predefinidos y,
//  si el dispositivo soporta Image Playground, sección para generar con IA.
//
//  FLUJO
//  -----
//  1. El usuario selecciona un estilo predefinido → toque → checkmark de selección.
//  2. Opcionalmente escribe una vibra y genera con Image Playground.
//  3. "Aplicar" confirma la selección en Professional y guarda en SwiftData.
//  4. "Cancelar" descarta pendientes y elimina archivos temporales no asignados.
//
//  UX
//  ---
//  - Transición con scale+opacity al aparecer el preview generado.
//  - Sin animaciones abruptas: los cambios de configuración se animan en AvatarView.
//  - Feedback claro de selección: checkmark superpuesto en el estilo activo.
//

import SwiftUI
import SwiftData
import ImagePlayground

struct AvatarSelectorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground

    @Bindable var viewModel: AvatarViewModel
    let professional: Professional

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    predefinedSection
                    if supportsImagePlayground {
                        aiSection
                    } else {
                        imagePlaygroundUnavailableSection
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .themedBackground()
            .navigationTitle("Cambiar avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        viewModel.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        viewModel.apply(to: professional, in: modelContext)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.hasPendingChanges)
                }
            }
            .imagePlaygroundSheet(
                isPresented: $viewModel.showingImagePlayground,
                concepts: viewModel.imagePlaygroundConcepts
            ) { url in
                withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                    viewModel.handleGeneratedImage(url: url)
                }
            }
        }
    }

    // MARK: - Sección predefinidos

    private var predefinedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Predefinidos")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 5),
                spacing: AppSpacing.sm
            ) {
                ForEach(PredefinedAvatarStyle.allCases) { style in
                    predefinedCell(style: style)
                }
            }
        }
    }

    private func predefinedCell(style: PredefinedAvatarStyle) -> some View {
        let isSelected: Bool = {
            switch viewModel.preview {
            case .predefined(let s): return s == style
            case .generated:         return false
            }
        }()

        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                viewModel.selectPredefined(style)
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(configuration: .predefined(style: style), size: .large)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, style.color)
                        .offset(x: 4, y: 4)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.spring(duration: 0.25, bounce: 0.3), value: isSelected)
    }

    // MARK: - Sección IA

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Crear con IA")

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Describe la vibra de tu avatar y Apple Intelligence lo generará.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Ej: profesional cálido, moderno, clínico", text: $viewModel.vibeText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                // Preview con fade+scale si hay imagen generada pendiente
                if case .generated = viewModel.preview, let image = viewModel.generatedImage {
                    generatedPreview(image: image)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Button {
                    viewModel.showingImagePlayground = true
                } label: {
                    Label("Generar con Image Playground", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.vibeText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(AppSpacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var imagePlaygroundUnavailableSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Crear con IA")

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("Image Playground no está disponible en este dispositivo.", systemImage: "sparkles.slash")
                    .font(.subheadline.weight(.medium))
                Text("Probá en un dispositivo compatible con Apple Intelligence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func generatedPreview(image: Image) -> some View {
        HStack(spacing: AppSpacing.sm) {
            AvatarView(
                configuration: viewModel.preview,
                size: .medium,
                generatedImage: image
            )
            VStack(alignment: .leading, spacing: 2) {
                Text("Imagen generada")
                    .font(.subheadline.weight(.medium))
                Text("Toca Aplicar para guardar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: Professional.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let professional = Professional(fullName: "Dra. Test", licenseNumber: "MN 99999")
    container.mainContext.insert(professional)

    return AvatarSelectorView(
        viewModel: AvatarViewModel(from: professional),
        professional: professional
    )
    .modelContainer(container)
}
