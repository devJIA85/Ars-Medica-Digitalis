//
//  PatientCreationHeader.swift
//  Ars Medica Digitalis
//
//  Encabezado de alta/edición de paciente con selector de foto.
//

import SwiftUI

struct PatientCreationHeader: View {

    @Bindable var viewModel: PatientViewModel

    var body: some View {
        CardContainer(style: .flat) {
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
        }
        .accessibilityElement(children: .contain)
    }
}
