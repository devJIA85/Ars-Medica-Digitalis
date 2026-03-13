//
//  PatientCreationSections.swift
//  Ars Medica Digitalis
//
//  Secciones modulares del formulario de alta/edición de pacientes.
//

import SwiftUI
import UIKit

struct PatientPersonalSection: View {

    @Bindable var viewModel: PatientViewModel
    let frequentCountryCodes: [String]

    var body: some View {
        PatientSectionCard(
            title: "Datos personales",
            accessibilityLabel: "Sección datos personales"
        ) {
            PatientLabeledTextField(
                title: "Nombre",
                prompt: "Agregar",
                text: $viewModel.firstName,
                contentType: .givenName,
                textInputAutocapitalization: .words
            )

            PatientLabeledTextField(
                title: "Apellido",
                prompt: "Agregar",
                text: $viewModel.lastName,
                contentType: .familyName,
                textInputAutocapitalization: .words
            )

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                DatePicker(
                    "Fecha de nacimiento",
                    selection: dateOfBirthBinding,
                    in: ...Date.now,
                    displayedComponents: .date
                )

                LabeledContent("Edad", value: ageLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            PatientSelectionMenuRow(
                title: "Género",
                value: selectedGenderLabel.text,
                isPlaceholder: selectedGenderLabel.isPlaceholder
            ) {
                ForEach(PatientViewModel.genderOptions, id: \.0) { value, label in
                    Button {
                        viewModel.gender = value
                    } label: {
                        optionLabel(
                            title: titleForOption(
                                value: value,
                                label: label,
                                placeholder: "Seleccionar"
                            ),
                            isSelected: viewModel.gender == value
                        )
                    }
                }
            }

            PatientSelectionMenuRow(
                title: "Estado civil",
                value: selectedMaritalStatusLabel.text,
                isPlaceholder: selectedMaritalStatusLabel.isPlaceholder
            ) {
                ForEach(PatientViewModel.maritalStatusOptions, id: \.0) { value, label in
                    Button {
                        viewModel.maritalStatus = value
                    } label: {
                        optionLabel(
                            title: titleForOption(
                                value: value,
                                label: label,
                                placeholder: "Seleccionar"
                            ),
                            isSelected: viewModel.maritalStatus == value
                        )
                    }
                }
            }

            NavigationLink {
                CountryPickerView(
                    selection: $viewModel.nationality,
                    frequentCodes: frequentCountryCodes
                )
                .navigationTitle("Nacionalidad")
            } label: {
                PatientSelectionRow(
                    title: "Nacionalidad",
                    value: selectedNationalityLabel.text,
                    isPlaceholder: selectedNationalityLabel.isPlaceholder,
                    indicator: .navigation
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CountryPickerView(
                    selection: $viewModel.residenceCountry,
                    frequentCodes: frequentCountryCodes
                )
                .navigationTitle("País de residencia")
            } label: {
                PatientSelectionRow(
                    title: "País de residencia",
                    value: selectedResidenceCountryLabel.text,
                    isPlaceholder: selectedResidenceCountryLabel.isPlaceholder,
                    indicator: .navigation
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var selectedGenderLabel: SelectionLabel {
        labelForSelection(
            viewModel.gender,
            options: PatientViewModel.genderOptions,
            placeholder: "Seleccionar"
        )
    }

    private var selectedMaritalStatusLabel: SelectionLabel {
        labelForSelection(
            viewModel.maritalStatus,
            options: PatientViewModel.maritalStatusOptions,
            placeholder: "Seleccionar"
        )
    }

    private var selectedNationalityLabel: SelectionLabel {
        labelForCountryCode(viewModel.nationality, placeholder: "Seleccionar")
    }

    private var selectedResidenceCountryLabel: SelectionLabel {
        labelForCountryCode(viewModel.residenceCountry, placeholder: "Seleccionar")
    }

    private var ageLabel: String {
        let years = max(
            Calendar.current.dateComponents([.year], from: viewModel.dateOfBirth, to: .now).year ?? 0,
            0
        )
        return years == 1 ? "1 año" : "\(years) años"
    }

    private var dateOfBirthBinding: Binding<Date> {
        Binding(
            get: { viewModel.dateOfBirth },
            set: { newValue in
                viewModel.dateOfBirth = newValue
                viewModel.markDateOfBirthAsEdited()
            }
        )
    }
}

struct PatientInfoSection: View {

    @Bindable var viewModel: PatientViewModel

    var body: some View {
        PatientSectionCard(
            title: "Información personal",
            accessibilityLabel: "Sección información personal"
        ) {
            PatientLabeledTextField(
                title: "Ocupación",
                prompt: "Agregar",
                text: $viewModel.occupation,
                textInputAutocapitalization: .words
            )

            PatientSelectionMenuRow(
                title: "Nivel académico",
                value: selectedEducationLevelLabel.text,
                isPlaceholder: selectedEducationLevelLabel.isPlaceholder
            ) {
                ForEach(PatientViewModel.educationLevelOptions, id: \.0) { value, label in
                    Button {
                        viewModel.educationLevel = value
                    } label: {
                        optionLabel(
                            title: titleForOption(
                                value: value,
                                label: label,
                                placeholder: "Elegir"
                            ),
                            isSelected: viewModel.educationLevel == value
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Estado clínico")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Picker("Estado clínico", selection: $viewModel.clinicalStatus) {
                    ForEach(PatientViewModel.clinicalStatusOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .tint(selectedClinicalStatusTint)
                .padding(.vertical, 4)
                .padding(.horizontal, AppSpacing.sm)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous))
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var selectedEducationLevelLabel: SelectionLabel {
        labelForSelection(
            viewModel.educationLevel,
            options: PatientViewModel.educationLevelOptions,
            placeholder: "Elegir"
        )
    }

    private var selectedClinicalStatusTint: Color {
        ClinicalStatusMapping(clinicalStatusRawValue: viewModel.clinicalStatus)?.tint ?? .accentColor
    }
}

struct PatientCoverageSection: View {

    @Bindable var viewModel: PatientViewModel

    var body: some View {
        PatientSectionCard(
            title: "Identificación y cobertura",
            accessibilityLabel: "Sección identificación y cobertura"
        ) {
            PatientLabeledTextField(
                title: "Documento de identidad",
                prompt: "Agregar",
                text: $viewModel.nationalId,
                keyboardType: .numberPad
            )

            PatientLabeledTextField(
                title: "Obra social",
                prompt: "Agregar",
                text: $viewModel.healthInsurance,
                textInputAutocapitalization: .words
            )

            PatientLabeledTextField(
                title: "Número de afiliado",
                prompt: "Agregar",
                text: $viewModel.insuranceMemberNumber,
                keyboardType: .numberPad
            )

            PatientLabeledTextField(
                title: "Plan",
                prompt: "Agregar",
                text: $viewModel.insurancePlan,
                textInputAutocapitalization: .words
            )
        }
    }
}

struct PatientContactSection: View {

    @Bindable var viewModel: PatientViewModel

    var body: some View {
        PatientSectionCard(
            title: "Contacto del paciente",
            accessibilityLabel: "Sección contacto del paciente"
        ) {
            PatientLabeledTextField(
                title: "Email",
                prompt: "Agregar",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                contentType: .emailAddress,
                textInputAutocapitalization: .never,
                autocorrectionDisabled: true
            )

            PatientLabeledTextField(
                title: "Teléfono",
                prompt: "Agregar",
                text: $viewModel.phoneNumber,
                keyboardType: .phonePad,
                contentType: .telephoneNumber
            )

            PatientLabeledTextField(
                title: "Dirección",
                prompt: "Agregar",
                text: $viewModel.address,
                contentType: .fullStreetAddress
            )
        }
    }
}

struct EmergencyContactSection: View {

    @Bindable var viewModel: PatientViewModel

    var body: some View {
        PatientSectionCard(
            title: "Contacto de emergencia",
            accessibilityLabel: "Sección contacto de emergencia"
        ) {
            PatientLabeledTextField(
                title: "Nombre",
                prompt: "Agregar",
                text: $viewModel.emergencyContactName,
                textInputAutocapitalization: .words
            )

            PatientLabeledTextField(
                title: "Teléfono",
                prompt: "Agregar",
                text: $viewModel.emergencyContactPhone,
                keyboardType: .phonePad
            )

            PatientSelectionMenuRow(
                title: "Vínculo",
                value: selectedEmergencyRelationLabel.text,
                isPlaceholder: selectedEmergencyRelationLabel.isPlaceholder
            ) {
                ForEach(PatientViewModel.emergencyRelationOptions, id: \.0) { value, label in
                    Button {
                        viewModel.emergencyContactRelation = value
                    } label: {
                        optionLabel(
                            title: titleForOption(
                                value: value,
                                label: label,
                                placeholder: "Seleccionar"
                            ),
                            isSelected: viewModel.emergencyContactRelation == value
                        )
                    }
                }
            }
        }
    }

    private var selectedEmergencyRelationLabel: SelectionLabel {
        labelForSelection(
            viewModel.emergencyContactRelation,
            options: PatientViewModel.emergencyRelationOptions,
            placeholder: "Seleccionar"
        )
    }
}

struct PatientFinanceSection: View {

    @Bindable var viewModel: PatientViewModel

    var body: some View {
        PatientSectionCard(
            title: "Finanzas",
            accessibilityLabel: "Sección finanzas"
        ) {
            PatientSelectionMenuRow(
                title: "Moneda predeterminada",
                value: selectedCurrencyLabel.text,
                isPlaceholder: selectedCurrencyLabel.isPlaceholder
            ) {
                Button {
                    viewModel.currencyCode = ""
                } label: {
                    optionLabel(
                        title: "Elegir",
                        isSelected: viewModel.currencyCode.isEmpty
                    )
                }

                ForEach(PatientViewModel.supportedCurrencies) { currency in
                    Button {
                        viewModel.currencyCode = currency.code
                    } label: {
                        optionLabel(
                            title: currency.displayLabel,
                            isSelected: viewModel.currencyCode == currency.code
                        )
                    }
                }
            }

            Text("Se usa para resolver la moneda de la sesión al momento del cobro.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var selectedCurrencyLabel: SelectionLabel {
        let normalizedCode = viewModel.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCode.isEmpty == false else {
            return SelectionLabel(text: "Elegir", isPlaceholder: true)
        }

        let displayName = PatientViewModel.supportedCurrencies
            .first(where: { $0.code == normalizedCode })?
            .displayLabel ?? normalizedCode
        return SelectionLabel(text: displayName, isPlaceholder: false)
    }
}

// MARK: - Shared Form Components

private struct PatientSectionCard<Content: View>: View {

    let title: String
    let accessibilityLabel: String
    @ViewBuilder var content: Content

    var body: some View {
        CardContainer(title: title, style: .flat) {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PatientLabeledTextField: View {

    let title: String
    let prompt: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var textInputAutocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(textInputAutocapitalization)
                .textContentType(contentType)
                .autocorrectionDisabled(autocorrectionDisabled)
        }
    }
}

private struct PatientSelectionMenuRow<MenuContent: View>: View {

    let title: String
    let value: String
    let isPlaceholder: Bool
    @ViewBuilder var menuContent: MenuContent

    var body: some View {
        Menu {
            menuContent
        } label: {
            PatientSelectionRow(
                title: title,
                value: value,
                isPlaceholder: isPlaceholder,
                indicator: .menu
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PatientSelectionRow: View {

    enum Indicator {
        case menu
        case navigation
    }

    let title: String
    let value: String
    let isPlaceholder: Bool
    let indicator: Indicator

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: AppSpacing.sm)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(isPlaceholder ? .tertiary : .secondary)
                .multilineTextAlignment(.trailing)

            Image(systemName: indicator == .menu ? "chevron.up.chevron.down" : "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct SelectionLabel {
    let text: String
    let isPlaceholder: Bool
}

private func labelForSelection(
    _ value: String,
    options: [(String, String)],
    placeholder: String
) -> SelectionLabel {
    let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalizedValue.isEmpty == false else {
        return SelectionLabel(text: placeholder, isPlaceholder: true)
    }

    let label = options.first(where: { $0.0 == normalizedValue })?.1 ?? normalizedValue
    return SelectionLabel(text: label, isPlaceholder: false)
}

private func labelForCountryCode(
    _ code: String,
    placeholder: String
) -> SelectionLabel {
    let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalizedCode.isEmpty == false else {
        return SelectionLabel(text: placeholder, isPlaceholder: true)
    }

    return SelectionLabel(
        text: CountryCatalog.displayName(for: normalizedCode),
        isPlaceholder: false
    )
}

private func titleForOption(
    value: String,
    label: String,
    placeholder: String
) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? placeholder : label
}

private func optionLabel(title: String, isSelected: Bool) -> some View {
    HStack {
        Text(title)
        if isSelected {
            Image(systemName: "checkmark")
        }
    }
}
