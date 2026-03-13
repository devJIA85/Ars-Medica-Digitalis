//
//  PatientCreationHeader.swift
//  Ars Medica Digitalis
//
//  Encabezado de alta/edición de paciente con selector de foto.
//

import SwiftUI

struct PatientCreationHeader: View {

    @Bindable var viewModel: PatientViewModel
    let isEditing: Bool
    let onImportFromContacts: () -> Void

    var body: some View {
        CardContainer(style: .flat) {
            VStack(spacing: AppSpacing.md) {
                ProfilePhotoPickerView(
                    photoData: $viewModel.photoData,
                    genderHint: viewModel.gender.isEmpty
                    ? viewModel.biologicalSex
                    : viewModel.gender,
                    onResize: { viewModel.resizePhoto($0) },
                    presentationStyle: .prominent
                )
                .accessibilityLabel(
                    viewModel.photoData == nil
                    ? "Foto del paciente. Agregar foto."
                    : "Foto del paciente. Cambiar foto."
                )

                Button(action: onImportFromContacts) {
                    Label(
                        isEditing ? "Completar desde Contactos" : "Importar desde Contactos",
                        systemImage: "person.crop.circle.badge.plus"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
