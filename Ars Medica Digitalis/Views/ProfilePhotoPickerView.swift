//
//  ProfilePhotoPickerView.swift
//  Ars Medica Digitalis
//
//  Componente reutilizable para selección de foto de perfil del paciente.
//  Muestra una imagen circular si hay foto, o un avatar SF Symbol según
//  género si no hay imagen. Usa PhotosPicker nativo de SwiftUI.
//

import SwiftUI
import PhotosUI

nonisolated enum ProfilePhotoPresentationStyle: Equatable, Sendable {
    case compact
    case prominent
}

struct ProfilePhotoPickerView: View {

    @Binding var photoData: Data?

    /// Género/sexo del paciente para elegir avatar por defecto
    let genderHint: String

    /// Callback para redimensionar la imagen seleccionada
    var onResize: ((Data) -> Data?)?
    var presentationStyle: ProfilePhotoPresentationStyle = .compact

    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: presentationStyle == .prominent ? AppSpacing.sm : 8) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                if presentationStyle == .prominent {
                    prominentPhotoButton
                } else {
                    compactPhotoButton
                }
            }
            .buttonStyle(.plain)

            if presentationStyle == .prominent {
                prominentActions
            } else {
                compactActions
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: selectedItem) {
            loadPhoto()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func photoView(size: CGFloat) -> some View {
        if let photoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
        } else {
            // Avatar por defecto según género
            Image(systemName: defaultAvatarSymbol)
                .resizable()
                .scaledToFit()
                .padding(size * 0.2)
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(.quaternary, in: Circle())
        }
    }

    private var compactPhotoButton: some View {
        photoView(size: 80)
            .clipShape(Circle())
    }

    private var prominentPhotoButton: some View {
        ZStack(alignment: .bottomTrailing) {
            photoView(size: 116)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)

            Image(systemName: "camera.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(.tint, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                }
                .offset(x: -2, y: -2)
        }
    }

    private var compactActions: some View {
        HStack(spacing: 16) {
            Text(photoData == nil ? "Agregar foto" : "Cambiar")
                .font(.caption)
                .foregroundStyle(.tint)

            if photoData != nil {
                Button(role: .destructive) {
                    removePhoto()
                } label: {
                    Text("Quitar")
                        .font(.caption)
                }
            }
        }
    }

    private var prominentActions: some View {
        HStack(spacing: AppSpacing.sm) {
            Label(photoData == nil ? "Agregar foto" : "Cambiar foto", systemImage: "photo.badge.plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            if photoData != nil {
                Button("Quitar", role: .destructive) {
                    removePhoto()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var defaultAvatarSymbol: String {
        switch genderHint.lowercased() {
        case "masculino":
            return "figure.stand"
        case "femenino":
            return "figure.stand.dress"
        default:
            return "person.crop.circle.fill"
        }
    }

    // MARK: - Carga de foto

    private func loadPhoto() {
        guard let selectedItem else { return }
        Task {
            if let data = try? await selectedItem.loadTransferable(type: Data.self) {
                // Redimensionar si hay callback, sino guardar directo
                if let resizer = onResize, let resized = resizer(data) {
                    photoData = resized
                } else {
                    photoData = data
                }
            }
        }
    }

    private func removePhoto() {
        withAnimation {
            photoData = nil
            selectedItem = nil
        }
    }
}

