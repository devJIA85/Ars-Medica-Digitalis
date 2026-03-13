//
//  PatientFormContainer.swift
//  Ars Medica Digitalis
//
//  Contenedor principal del flujo de creación/edición de pacientes.
//

import SwiftUI

struct PatientCreationFlowView: View {

    @Bindable var viewModel: PatientViewModel
    @Bindable var flowState: PatientCreationState

    let frequentCountryCodes: [String]
    let isEditing: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                PatientCreationHeader(viewModel: viewModel)

                if flowState.isStepModeEnabled {
                    PatientStepProgressView(flowState: flowState)
                }

                PatientFormContainer(
                    viewModel: viewModel,
                    flowState: flowState,
                    frequentCountryCodes: frequentCountryCodes
                )
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl + AppSpacing.lg)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            PatientCreationFooter(
                flowState: flowState,
                isEditing: isEditing,
                canSave: viewModel.canSave,
                onCancel: onCancel,
                onSave: onSave
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                formModeMenu
            }
        }
    }

    private var formModeMenu: some View {
        Menu {
            Picker("Modo de formulario", selection: formModeBinding) {
                ForEach(PatientCreationState.PresentationMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
        } label: {
            Image(systemName: flowState.presentationMode.systemImage)
        }
        .accessibilityLabel("Cambiar modo del formulario")
    }

    private var formModeBinding: Binding<PatientCreationState.PresentationMode> {
        Binding(
            get: { flowState.presentationMode },
            set: { flowState.setPresentationMode($0) }
        )
    }
}

struct PatientFormContainer: View {

    @Bindable var viewModel: PatientViewModel
    @Bindable var flowState: PatientCreationState
    let frequentCountryCodes: [String]

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            if flowState.isStepModeEnabled {
                stepContent(for: flowState.currentStep)
            } else {
                fullFormContent
            }
        }
    }

    @ViewBuilder
    private var fullFormContent: some View {
        PatientPersonalSection(
            viewModel: viewModel,
            frequentCountryCodes: frequentCountryCodes
        )

        PatientInfoSection(viewModel: viewModel)
        PatientCoverageSection(viewModel: viewModel)
        PatientContactSection(viewModel: viewModel)
        EmergencyContactSection(viewModel: viewModel)
        PatientFinanceSection(viewModel: viewModel)
    }

    @ViewBuilder
    private func stepContent(for step: PatientCreationState.Step) -> some View {
        switch step {
        case .personal:
            PatientPersonalSection(
                viewModel: viewModel,
                frequentCountryCodes: frequentCountryCodes
            )
            PatientInfoSection(viewModel: viewModel)
        case .coverage:
            PatientCoverageSection(viewModel: viewModel)
        case .contact:
            PatientContactSection(viewModel: viewModel)
            EmergencyContactSection(viewModel: viewModel)
        case .finance:
            PatientFinanceSection(viewModel: viewModel)
        }
    }
}

private struct PatientStepProgressView: View {

    @Bindable var flowState: PatientCreationState

    var body: some View {
        CardContainer(style: .flat) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(flowState.stepSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(flowState.currentStep.title)
                    .font(.headline)

                ProgressView(value: flowState.progressValue)
                    .progressViewStyle(.linear)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(flowState.stepSummary). \(flowState.currentStep.title)")
    }
}

private struct PatientCreationFooter: View {

    @Bindable var flowState: PatientCreationState
    let isEditing: Bool
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(secondaryButtonTitle) {
                secondaryButtonAction()
            }
            .buttonStyle(.bordered)

            Spacer(minLength: AppSpacing.sm)

            Button(primaryButtonTitle) {
                primaryButtonAction()
            }
            .buttonStyle(.borderedProminent)
            .disabled(primaryButtonDisabled)
        }
        .padding(AppSpacing.md)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.25)
        }
    }

    private var secondaryButtonTitle: String {
        if flowState.isStepModeEnabled, flowState.canGoBack {
            return "Anterior"
        }
        return "Cancelar"
    }

    private var primaryButtonTitle: String {
        if flowState.isStepModeEnabled, flowState.canGoForward {
            return "Siguiente"
        }
        return isEditing ? "Guardar" : "Crear paciente"
    }

    private var primaryButtonDisabled: Bool {
        if flowState.isStepModeEnabled, flowState.canGoForward {
            return false
        }
        return canSave == false
    }

    private func secondaryButtonAction() {
        if flowState.isStepModeEnabled, flowState.canGoBack {
            flowState.goToPreviousStep()
            return
        }
        onCancel()
    }

    private func primaryButtonAction() {
        if flowState.isStepModeEnabled, flowState.canGoForward {
            flowState.goToNextStep()
            return
        }
        onSave()
    }
}
