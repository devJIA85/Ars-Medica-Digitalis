//
//  PatientContactImportViews.swift
//  Ars Medica Digitalis
//
//  Vistas auxiliares para importar un contacto del sistema y resolver
//  duplicados fuertes antes de persistir un paciente.
//

import Contacts
import ContactsUI
import SwiftUI

struct PatientContactPickerSheet: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> ContactPickerHostViewController {
        let controller = ContactPickerHostViewController()
        controller.onDidAppear = { hostController in
            context.coordinator.presentPickerIfNeeded(from: hostController)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: ContactPickerHostViewController, context: Context) {
        uiViewController.onDidAppear = { hostController in
            context.coordinator.presentPickerIfNeeded(from: hostController)
        }
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onSelect: (CNContact) -> Void
        private let onCancel: () -> Void
        private var hasPresentedPicker = false

        init(
            onSelect: @escaping (CNContact) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func presentPickerIfNeeded(from hostController: UIViewController) {
            guard hasPresentedPicker == false,
                  hostController.presentedViewController == nil else {
                return
            }

            hasPresentedPicker = true

            let picker = CNContactPickerViewController()
            picker.delegate = self
            picker.predicateForSelectionOfContact = NSPredicate(value: true)

            // Presentarlo desde un host UIKit evita los fallos de render/XPC
            // que aparecen al embeber CNContactPickerViewController en un sheet SwiftUI.
            DispatchQueue.main.async {
                hostController.present(picker, animated: true)
            }
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }
}

final class ContactPickerHostViewController: UIViewController {
    var onDidAppear: ((UIViewController) -> Void)?
    private var hasAppeared = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard hasAppeared == false else {
            return
        }

        hasAppeared = true
        onDidAppear?(self)
    }
}

struct PatientDuplicateResolutionSheet: View {
    let match: PatientContactDuplicateMatch
    let onUseExisting: () -> Void
    let onCreateNew: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                patientSummary
                actions
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .navigationTitle("Posible duplicado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        onCancel()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(match.reason.title)
                .font(.headline)

            Text(match.reason.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Podés seguir con el paciente existente o forzar la creación de uno nuevo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var patientSummary: some View {
        CardContainer(style: .flat) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                PatientAvatarView(
                    photoData: match.patient.photoData,
                    firstName: match.patient.firstName,
                    lastName: match.patient.lastName,
                    genderHint: match.patient.gender.isEmpty ? match.patient.biologicalSex : match.patient.gender,
                    clinicalStatus: match.patient.clinicalStatus,
                    size: 54
                )

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(match.patient.fullName.trimmed)
                            .font(.headline)
                        statusBadge
                    }

                    if match.patient.medicalRecordNumber.isEmpty == false {
                        Text(match.patient.medicalRecordNumber)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if contactSummary.isEmpty == false {
                        Text(contactSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            Button("Usar paciente existente") {
                onUseExisting()
            }
            .buttonStyle(.borderedProminent)

            Button("Crear nuevo") {
                onCreateNew()
            }
            .buttonStyle(.bordered)

            Button("Cancelar", role: .cancel) {
                onCancel()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusBadge: some View {
        Text(match.patient.isActive ? "Activo" : "Inactivo")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(
                match.patient.isActive ? Color.green.opacity(0.14) : Color.orange.opacity(0.14),
                in: Capsule()
            )
            .foregroundStyle(match.patient.isActive ? Color.green : Color.orange)
    }

    private var contactSummary: String {
        let parts = [
            match.patient.email.trimmed,
            match.patient.phoneNumber.trimmed,
        ]
        .filter { $0.isEmpty == false }

        return parts.joined(separator: " · ")
    }
}
