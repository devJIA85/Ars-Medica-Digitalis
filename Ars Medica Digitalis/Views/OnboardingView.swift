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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = ProfessionalViewModel()
    @State private var saveErrorMessage: String?

    // Callback para notificar a ContentView que el registro se completó
    var onComplete: () -> Void

    private var layout: OnboardingLayout {
        OnboardingLayout.resolved(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        @Bindable var formViewModel = viewModel

        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: layout.sectionSpacing) {
                    heroCard

                    professionalDataCard(
                        fullName: $formViewModel.fullName,
                        specialty: $formViewModel.specialty,
                        licenseNumber: $formViewModel.licenseNumber
                    )

                    initialConfigCard(
                        email: $formViewModel.email,
                        defaultPatientCurrencyCode: $formViewModel.defaultPatientCurrencyCode
                    )

                    createProfileButton(isEnabled: canCreateProfile(for: formViewModel))
                }
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.top, layout.topPadding)
                .padding(.bottom, layout.bottomPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .background { onboardingBackground }
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("No se pudo crear el perfil", isPresented: $saveErrorMessage.isPresent) {
            Button("Aceptar", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Intenta nuevamente.")
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color.cyan.opacity(0.10),
                    Color.blue.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.55))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: -150, y: -260)

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 44)
                .offset(x: 150, y: -120)

            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 56)
                .offset(x: 120, y: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var heroCard: some View {
        CardContainer(style: .elevated, usesGlassEffect: false) {
            VStack(alignment: .leading, spacing: layout.heroSpacing) {
                Text("Bienvenido")
                    .font(.system(size: layout.titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(alignment: .center, spacing: layout.heroSpacing) {
                    RoundedRectangle(cornerRadius: layout.heroIconCornerRadius, style: .continuous)
                        .fill(.thinMaterial)
                        .frame(width: layout.heroIconSize, height: layout.heroIconSize)
                        .overlay {
                            Image(systemName: "stethoscope")
                                .font(.system(size: layout.heroSymbolSize, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .symbolColorRenderingMode(.gradient)
                                .foregroundStyle(.tint)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: layout.heroIconCornerRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.20))
                        }

                    VStack(alignment: .leading, spacing: layout.copySpacing) {
                        Text("Ars Medica Digitalis")
                            .font(.system(size: layout.brandSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Configurá tu perfil profesional para comenzar a gestionar historias clínicas.")
                            .font(.system(size: layout.subtitleSize, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func professionalDataCard(
        fullName: Binding<String>,
        specialty: Binding<String>,
        licenseNumber: Binding<String>
    ) -> some View {
        CardContainer(style: .flat, usesGlassEffect: false) {
            VStack(alignment: .leading, spacing: layout.contentSpacing) {
                sectionHeader(title: "Datos profesionales", systemImage: "person.text.rectangle")

                VStack(spacing: layout.fieldSpacing) {
                    onboardingField(
                        title: "Nombre completo",
                        text: fullName,
                        accessibilityID: "onboarding.fullName",
                        textContentType: .name,
                        autocapitalizationType: .words
                    )

                    onboardingField(
                        title: "Especialidad",
                        text: specialty,
                        accessibilityID: "onboarding.specialty",
                        autocapitalizationType: .words
                    )

                    onboardingField(
                        title: "Número de matrícula",
                        text: licenseNumber,
                        accessibilityID: "onboarding.licenseNumber",
                        autocapitalizationType: .allCharacters
                    )
                }
            }
        }
    }

    private func initialConfigCard(
        email: Binding<String>,
        defaultPatientCurrencyCode: Binding<String>
    ) -> some View {
        CardContainer(style: .flat, usesGlassEffect: false) {
            VStack(alignment: .leading, spacing: layout.contentSpacing) {
                sectionHeader(title: "Configuración inicial", systemImage: "wallet.pass")

                currencySelector(
                    defaultPatientCurrencyCode: defaultPatientCurrencyCode,
                    selectedCurrencyLabel: selectedCurrencyLabel(for: defaultPatientCurrencyCode.wrappedValue)
                )

                onboardingField(
                    title: "Email (opcional)",
                    text: email,
                    accessibilityID: "onboarding.email",
                    textContentType: .emailAddress,
                    keyboardType: .emailAddress,
                    autocapitalizationType: .none
                )
            }
        }
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .font(.headline.weight(.semibold))
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
    }

    private func onboardingField(
        title: String,
        text: Binding<String>,
        accessibilityID: String,
        textContentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)

        return OnboardingUIKitField(
            title: title,
            text: text,
            accessibilityID: accessibilityID,
            textContentType: textContentType,
            keyboardType: keyboardType,
            autocapitalizationType: autocapitalizationType
        )
        .padding(.horizontal, layout.fieldHorizontalPadding)
        .frame(height: layout.fieldHeight)
        .background(.ultraThinMaterial, in: shape)
        .overlay {
            shape.strokeBorder(.white.opacity(0.18))
                .allowsHitTesting(false)
        }
    }

    private func currencySelector(
        defaultPatientCurrencyCode: Binding<String>,
        selectedCurrencyLabel: String
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)

        return Menu {
            Button("Elegir") {
                defaultPatientCurrencyCode.wrappedValue = ""
            }

            ForEach(CurrencyCatalog.common) { currency in
                Button(currency.displayLabel) {
                    defaultPatientCurrencyCode.wrappedValue = currency.code
                }
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moneda predeterminada")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("Se aplicará a pacientes nuevos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: AppSpacing.md)

                HStack(spacing: AppSpacing.xs) {
                    Text(selectedCurrencyLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(defaultPatientCurrencyCode.wrappedValue.isEmpty ? .secondary : .primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, layout.fieldHorizontalPadding)
            .frame(height: layout.currencyRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(.white.opacity(0.18))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
    }

    private func createProfileButton(isEnabled: Bool) -> some View {
        Button(action: save) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.multicolor)

                Text("Crear Perfil")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: layout.buttonHeight)
        }
        .buttonStyle(.glass)
        .tint(.accentColor)
        .disabled(!isEnabled)
        .accessibilityIdentifier("onboarding.createProfile")
    }

    private func selectedCurrencyLabel(for code: String) -> String {
        let normalizedCode = code.trimmed.uppercased()
        guard normalizedCode.isEmpty == false else { return "Elegir" }
        return CurrencyCatalog.label(for: normalizedCode)
    }

    private func canCreateProfile(for viewModel: ProfessionalViewModel) -> Bool {
        viewModel.canSave
        && viewModel.defaultPatientCurrencyCode.trimmed.isEmpty == false
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
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.delegate = context.coordinator
        textField.accessibilityIdentifier = accessibilityID
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )

        let assistant = textField.inputAssistantItem
        assistant.leadingBarButtonGroups = []
        assistant.trailingBarButtonGroups = []

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

private struct OnboardingLayout {
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let sectionSpacing: CGFloat
    let contentSpacing: CGFloat
    let fieldSpacing: CGFloat
    let heroSpacing: CGFloat
    let copySpacing: CGFloat
    let titleSize: CGFloat
    let brandSize: CGFloat
    let subtitleSize: CGFloat
    let heroIconSize: CGFloat
    let heroSymbolSize: CGFloat
    let heroIconCornerRadius: CGFloat
    let fieldHeight: CGFloat
    let currencyRowHeight: CGFloat
    let fieldHorizontalPadding: CGFloat
    let buttonHeight: CGFloat

    static func resolved(dynamicTypeSize: DynamicTypeSize) -> OnboardingLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return compactAccessibility
        }

        if dynamicTypeSize > .large {
            return compact
        }

        return regular
    }

    static let regular = OnboardingLayout(
        horizontalPadding: 20,
        topPadding: 16,
        bottomPadding: 16,
        sectionSpacing: 16,
        contentSpacing: 14,
        fieldSpacing: 12,
        heroSpacing: 14,
        copySpacing: 6,
        titleSize: 40,
        brandSize: 26,
        subtitleSize: 16,
        heroIconSize: 76,
        heroSymbolSize: 34,
        heroIconCornerRadius: 24,
        fieldHeight: 54,
        currencyRowHeight: 66,
        fieldHorizontalPadding: 16,
        buttonHeight: 54
    )

    static let compact = OnboardingLayout(
        horizontalPadding: 16,
        topPadding: 10,
        bottomPadding: 14,
        sectionSpacing: 12,
        contentSpacing: 12,
        fieldSpacing: 10,
        heroSpacing: 12,
        copySpacing: 4,
        titleSize: 34,
        brandSize: 24,
        subtitleSize: 15,
        heroIconSize: 68,
        heroSymbolSize: 30,
        heroIconCornerRadius: 22,
        fieldHeight: 50,
        currencyRowHeight: 62,
        fieldHorizontalPadding: 14,
        buttonHeight: 50
    )

    static let compactAccessibility = OnboardingLayout(
        horizontalPadding: 16,
        topPadding: 8,
        bottomPadding: 12,
        sectionSpacing: 10,
        contentSpacing: 10,
        fieldSpacing: 8,
        heroSpacing: 10,
        copySpacing: 4,
        titleSize: 28,
        brandSize: 22,
        subtitleSize: 14,
        heroIconSize: 60,
        heroSymbolSize: 26,
        heroIconCornerRadius: 20,
        fieldHeight: 46,
        currencyRowHeight: 58,
        fieldHorizontalPadding: 14,
        buttonHeight: 48
    )
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: Professional.self, inMemory: true)
}
