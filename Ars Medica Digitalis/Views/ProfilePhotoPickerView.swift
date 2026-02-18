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

struct ProfilePhotoPickerView: View {

    @Binding var photoData: Data?

    /// Género/sexo del paciente para elegir avatar por defecto
    let genderHint: String

    /// Callback para redimensionar la imagen seleccionada
    var onResize: ((Data) -> Data?)?

    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        HStack {
            Spacer()

            VStack(spacing: 8) {
                photoView
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())

                HStack(spacing: 16) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text(photoData == nil ? "Agregar foto" : "Cambiar")
                            .font(.caption)
                    }

                    if photoData != nil {
                        Button(role: .destructive) {
                            withAnimation {
                                photoData = nil
                                selectedItem = nil
                            }
                        } label: {
                            Text("Quitar")
                                .font(.caption)
                        }
                    }
                }
            }

            Spacer()
        }
        .onChange(of: selectedItem) {
            loadPhoto()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var photoView: some View {
        if let photoData, let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            // Avatar por defecto según género
            Image(systemName: defaultAvatarSymbol)
                .resizable()
                .scaledToFit()
                .padding(16)
                .foregroundStyle(.secondary)
                .background(.quaternary, in: Circle())
        }
    }

    private var defaultAvatarSymbol: String {
        switch genderHint.lowercased() {
        case "masculino": "figure.stand"
        case "femenino": "figure.stand.dress"
        default: "person.crop.circle.fill"
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
}
