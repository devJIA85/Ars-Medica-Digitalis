//
//  PatientFormView.swift
//  Ars Medica Digitalis
//
//  Formulario para alta (HU-02) y edición (HU-03) de pacientes.
//  Se enfoca en datos demográficos, identificación y contacto.
//  La historia clínica se gestiona desde PatientMedicalHistoryView.
//

import SwiftUI
import SwiftData
import Contacts
import OSLog

struct PatientFormView: View {

    private let logger = Logger(subsystem: "com.arsmedica.digitalis", category: "PatientFormView")

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.auditService) private var auditService
    // TODO: [Audit Trail] Inyectar currentActorID desde ContentView:
    // .environment(\.currentActorID, professional.id.uuidString)
    @Environment(\.currentActorID) private var currentActorID

    let professional: Professional

    /// nil = modo alta, non-nil = modo edición
    let patient: Patient?

    // @State preserva el VM entre re-renders del padre (sheets, etc.)
    // @Bindable no lo hacía → se recreaba vacío y se perdían datos.
    @State private var viewModel: PatientViewModel
    @State private var flowState = PatientCreationState()
    @State private var targetPatient: Patient?
    @State private var showingContactPicker: Bool = false
    @State private var duplicateMatch: PatientContactDuplicateMatch? = nil
    @State private var pendingImportedContact: ImportedContactDraft? = nil
    @State private var overwritePrompt: ImportedContactOverwritePrompt? = nil
    @State private var importErrorMessage: String? = nil

    private var isEditing: Bool { targetPatient != nil }

    /// Países frecuentes calculados a partir de los pacientes del profesional
    private var frequentCountryCodes: [String] {
        CountryCatalog.frequentCodes(from: professional.patients)
    }

    init(professional: Professional, patient: Patient? = nil) {
        self.professional = professional
        self.patient = patient

        let vm = PatientViewModel()
        if let patient {
            vm.load(from: patient)
        } else {
            // Sembramos la moneda default del profesional solo en altas nuevas
            // para no pisar configuraciones ya existentes del paciente.
            vm.applyCreationDefaults(from: professional)
        }
        _viewModel = State(initialValue: vm)
        _targetPatient = State(initialValue: patient)
    }

    var body: some View {
        PatientCreationFlowView(
            viewModel: viewModel,
            flowState: flowState,
            frequentCountryCodes: frequentCountryCodes,
            isEditing: isEditing,
            onCancel: { dismiss() },
            onImportContact: { showingContactPicker = true },
            onSave: save
        )
        .navigationTitle(isEditing ? "Editar Paciente" : "Nuevo Paciente")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingContactPicker) {
            PatientContactPickerSheet(
                onSelect: handleImportedContactSelection,
                onCancel: { showingContactPicker = false }
            )
        }
        .sheet(
            item: $duplicateMatch,
            onDismiss: {
                if overwritePrompt == nil {
                    pendingImportedContact = nil
                }
            }
        ) { match in
            PatientDuplicateResolutionSheet(
                match: match,
                onUseExisting: { useExistingPatient(match) },
                onCreateNew: continueImportAfterDuplicateWarning,
                onCancel: clearPendingImportedContact
            )
        }
        .confirmationDialog(
            "Reemplazar datos existentes",
            isPresented: overwritePromptBinding,
            titleVisibility: .visible
        ) {
            Button("Solo completar vacíos") {
                applyPendingImportedContact(mode: .fillEmpty)
            }

            Button("Reemplazar datos existentes") {
                applyPendingImportedContact(mode: .overwriteExisting)
            }

            Button("Cancelar", role: .cancel) {
                clearPendingImportedContact()
            }
        } message: {
            Text(overwritePrompt?.message ?? "")
        }
        .alert(
            "No se pudo importar el contacto",
            isPresented: importErrorBinding
        ) {
            Button("Aceptar", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "Ocurrió un error al leer el contacto seleccionado.")
        }
        .onAppear {
            flowState.adaptPresentationModeIfNeeded(
                verticalSizeClass: verticalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )
        }
        .onChange(of: verticalSizeClass) {
            flowState.adaptPresentationModeIfNeeded(
                verticalSizeClass: verticalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )
        }
        .onChange(of: dynamicTypeSize) {
            flowState.adaptPresentationModeIfNeeded(
                verticalSizeClass: verticalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )
        }
    }

    // MARK: - Acciones

    private func save() {
        if let targetPatient {
            viewModel.update(targetPatient, in: modelContext)
            auditService.log(action: .update, on: targetPatient, in: modelContext, performedBy: currentActorID)
        } else {
            let newPatient = viewModel.createPatient(for: professional, in: modelContext)
            auditService.log(action: .create, on: newPatient, in: modelContext, performedBy: currentActorID)
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("Patient form save failed: \(error, privacy: .private)")
        }
        dismiss()
    }

    private func handleImportedContactSelection(_ contact: CNContact) {
        showingContactPicker = false

        guard let draft = ImportedContactDraft(
            contact: contact,
            imageResizer: { viewModel.resizePhoto($0) }
        ) else {
            importErrorMessage = "El contacto seleccionado no tiene nombre y apellido utilizables."
            return
        }

        if let match = PatientContactImportService.findDuplicate(
            for: draft,
            among: professionalPatients(),
            excluding: targetPatient?.id
        ) {
            pendingImportedContact = draft
            duplicateMatch = match
            return
        }

        prepareImportedContact(draft)
    }

    private func prepareImportedContact(_ draft: ImportedContactDraft) {
        pendingImportedContact = draft

        let overwriteFields = viewModel.overwriteFields(for: draft)
        if overwriteFields.isEmpty {
            applyPendingImportedContact(mode: .fillEmpty)
            return
        }

        overwritePrompt = ImportedContactOverwritePrompt(fields: overwriteFields)
    }

    private func continueImportAfterDuplicateWarning() {
        duplicateMatch = nil

        guard let draft = pendingImportedContact else {
            return
        }

        let overwriteFields = viewModel.overwriteFields(for: draft)
        if overwriteFields.isEmpty {
            applyPendingImportedContact(mode: .fillEmpty)
        } else {
            overwritePrompt = ImportedContactOverwritePrompt(fields: overwriteFields)
        }
    }

    private func useExistingPatient(_ match: PatientContactDuplicateMatch) {
        duplicateMatch = nil
        targetPatient = match.patient
        viewModel.load(from: match.patient)

        guard let draft = pendingImportedContact else {
            return
        }

        let overwriteFields = viewModel.overwriteFields(for: draft)
        if overwriteFields.isEmpty {
            applyPendingImportedContact(mode: .fillEmpty)
        } else {
            overwritePrompt = ImportedContactOverwritePrompt(fields: overwriteFields)
        }
    }

    private func applyPendingImportedContact(mode: ImportedContactMergeMode) {
        guard let draft = pendingImportedContact else {
            return
        }

        viewModel.apply(importedContact: draft, mode: mode)
        pendingImportedContact = nil
        overwritePrompt = nil
    }

    private func clearPendingImportedContact() {
        duplicateMatch = nil
        pendingImportedContact = nil
        overwritePrompt = nil
    }

    private func professionalPatients() -> [Patient] {
        let professionalID = professional.id
        let descriptor = FetchDescriptor<Patient>(
            predicate: #Predicate<Patient> { candidate in
                candidate.professional?.id == professionalID
            },
            sortBy: [SortDescriptor(\Patient.updatedAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? professional.patients
    }

    private var overwritePromptBinding: Binding<Bool> {
        Binding(
            get: { overwritePrompt != nil },
            set: { isPresented in
                if isPresented == false {
                    overwritePrompt = nil
                }
            }
        )
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    importErrorMessage = nil
                }
            }
        )
    }
}

private struct ImportedContactOverwritePrompt {
    let fields: [String]

    var message: String {
        guard fields.isEmpty == false else {
            return "El contacto tiene datos para completar en la ficha."
        }

        return "El contacto seleccionado también trae valores para \(fields.joined(separator: ", ")). Elegí si querés completar solo los campos vacíos o reemplazar los datos actuales."
    }
}

#Preview("Alta") {
    NavigationStack {
        PatientFormView(
            professional: Professional(
                fullName: "Dr. Test",
                licenseNumber: "MN 999",
                specialty: "Psicología"
            )
        )
    }
    .modelContainer(ModelContainer.preview)
}

#Preview("Edición") {
    NavigationStack {
        PatientFormView(
            professional: Professional(
                fullName: "Dr. Test",
                licenseNumber: "MN 999",
                specialty: "Psicología"
            ),
            patient: Patient(
                firstName: "Ana",
                lastName: "García",
                email: "ana@example.com"
            )
        )
    }
    .modelContainer(ModelContainer.preview)
}
