//
//  OnboardingView.swift
//  Ars Medica Digitalis
//
//  Pantalla de registro inicial del profesional (HU-01).
//  Se muestra únicamente cuando no existe un Professional en SwiftData.
//

import SwiftUI
import SwiftData
import UIKit

struct OnboardingView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = ProfessionalViewModel()
    @State private var saveErrorMessage: String?

    // Callback para notificar a ContentView que el registro se completó
    var onComplete: () -> Void

    var body: some View {
        @Bindable var formViewModel = viewModel

        NavigationStack {
            Form {
                headerSection

                professionalDataSection(
                    fullName: $formViewModel.fullName,
                    specialty: $formViewModel.specialty,
                    licenseNumber: $formViewModel.licenseNumber
                )

                initialConfigSection(
                    email: $formViewModel.email,
                    defaultPatientCurrencyCode: $formViewModel.defaultPatientCurrencyCode
                )

                Section {
                    Button("Crear Perfil", action: save)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(!canCreateProfile(for: formViewModel))
                        .accessibilityIdentifier("onboarding.createProfile")
                }
            }
            .navigationTitle("Bienvenido")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("No se pudo crear el perfil", isPresented: saveErrorBinding) {
            Button("Aceptar", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Intenta nuevamente.")
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Ars Medica Digitalis")
                    .font(.title2.weight(.semibold))

                Text("Configurá tu perfil profesional para comenzar a gestionar historias clínicas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, AppSpacing.xs)
        }
    }

    private func professionalDataSection(
        fullName: Binding<String>,
        specialty: Binding<String>,
        licenseNumber: Binding<String>
    ) -> some View {
        Section("Datos profesionales") {
            OnboardingUIKitField(
                title: "Nombre completo",
                text: fullName,
                accessibilityID: "onboarding.fullName",
                textContentType: .name,
                autocapitalizationType: .words
            )

            OnboardingUIKitField(
                title: "Especialidad",
                text: specialty,
                accessibilityID: "onboarding.specialty",
                autocapitalizationType: .words
            )

            OnboardingUIKitField(
                title: "Número de matrícula",
                text: licenseNumber,
                accessibilityID: "onboarding.licenseNumber",
                autocapitalizationType: .allCharacters
            )
        }
    }

    private func initialConfigSection(
        email: Binding<String>,
        defaultPatientCurrencyCode: Binding<String>
    ) -> some View {
        Section("Configuración inicial") {
            Picker("Moneda predeterminada", selection: defaultPatientCurrencyCode) {
                Text("Elegir").tag("")
                ForEach(CurrencyCatalog.common) { currency in
                    Text(currency.displayLabel).tag(currency.code)
                }
            }

            OnboardingUIKitField(
                title: "Email (opcional)",
                text: email,
                accessibilityID: "onboarding.email",
                textContentType: .emailAddress,
                keyboardType: .emailAddress,
                autocapitalizationType: .none
            )
        }
    }

    private func canCreateProfile(for viewModel: ProfessionalViewModel) -> Bool {
        viewModel.canSave
        && viewModel.defaultPatientCurrencyCode.trimmed.isEmpty == false
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    saveErrorMessage = nil
                }
            }
        )
    }

    // MARK: - Acciones

    private func save() {
        do {
            viewModel.createProfessional(in: modelContext)
            try modelContext.save()
            onComplete()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

private struct OnboardingUIKitField: UIViewRepresentable {

    let title: String
    @Binding var text: String
    let accessibilityID: String
    var textContentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .sentences

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.placeholder = title
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.textContentType = textContentType
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.returnKeyType = .next
        textField.delegate = context.coordinator
        textField.accessibilityIdentifier = accessibilityID
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }

        textField.placeholder = title
        textField.textContentType = textContentType
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.accessibilityIdentifier = accessibilityID
    }

    final class Coordinator: NSObject, UITextFieldDelegate {

        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: Professional.self, inMemory: true)
}
