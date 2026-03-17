//
//  PatientListView.swift
//  Ars Medica Digitalis
//
//  Lista principal de pacientes con búsqueda y filtro activos/inactivos (HU-02, HU-03).
//  La búsqueda usa #Predicate — type-safe y sin latencia de red.
//

import SwiftUI
import SwiftData

struct PatientListView: View {

    let professional: Professional

    /// Namespace compartido con ContentView para la transición zoom
    /// entre la fila del paciente y su vista de detalle.
    let namespace: Namespace.ID
    let onAddPatient: () -> Void
    var enablesSearch: Bool = true

    @State private var searchText: String = ""
    @State private var showInactive: Bool = false
    @State private var patientToDelete: Patient? = nil

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        let dashboard = PatientFilteredList(
            searchText: searchText,
            showInactive: showInactive,
            professional: professional,
            namespace: namespace,
            onDelete: { patient in
                patientToDelete = patient
            }
        )
            .navigationTitle(showInactive ? "Inactivos" : "Pacientes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showInactive.toggle()
                    } label: {
                        Image(systemName: showInactive ? "person.fill" : "person.slash")
                            .accessibilityLabel(showInactive ? "Ver Activos" : "Ver Inactivos")
                    }
                    .buttonStyle(.glass)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onAddPatient()
                    } label: {
                        Label("Nuevo", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Agregar nuevo paciente")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView(professional: professional)
                    } label: {
                        Label("Perfil", systemImage: "person.crop.circle")
                    }
                    .accessibilityIdentifier("main.profile")
                }

                // El CTA principal vive en el top bar, junto a perfil.
            }
            // Diálogo de confirmación para baja lógica (HU-03)
            .confirmationDialog(
                "¿Dar de baja a este paciente?",
                isPresented: Binding(
                    get: { patientToDelete != nil },
                    set: { if !$0 { patientToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Dar de Baja", role: .destructive) {
                    if let patient = patientToDelete {
                        patient.deletedAt = Date()
                        patient.updatedAt = Date()
                        patientToDelete = nil
                    }
                }
            } message: {
                Text("El paciente desaparecerá de la lista principal. Su historia clínica se conservará íntegra.")
            }

        if enablesSearch {
            dashboard.searchable(text: $searchText, placement: .automatic, prompt: "Buscar paciente")
        } else {
            dashboard
        }
    }
}

// MARK: - Sublista filtrada con #Predicate

/// Vista interna que ejecuta el @Query con filtros dinámicos.
/// Separada porque #Predicate necesita ser construido antes del body
/// y @Query no acepta parámetros dinámicos inline.
private struct PatientFilteredList: View {

    @Query private var patients: [Patient]
    @State private var store = PatientDashboardStore()
    @Environment(\.modelContext) private var modelContext

    let professional: Professional
    let onDelete: (Patient) -> Void
    let namespace: Namespace.ID

    init(
        searchText: String,
        showInactive: Bool,
        professional: Professional,
        namespace: Namespace.ID,
        onDelete: @escaping (Patient) -> Void
    ) {
        self.professional = professional
        self.onDelete = onDelete
        self.namespace = namespace

        let trimmed = searchText.trimmed.lowercased()
        let searchIsEmpty = trimmed.isEmpty
        let shouldShowInactive = showInactive
        let currentProfessionalID = professional.id

        // #Predicate filtra por estado activo/inactivo y texto de búsqueda.
        // Todo se resuelve localmente en SwiftData, sin llamadas de red.
        _patients = Query(
            filter: #Predicate<Patient> { patient in
                patient.professional?.id == currentProfessionalID
                && ((patient.deletedAt != nil) == shouldShowInactive)
                && (
                    searchIsEmpty
                    || patient.firstName.localizedStandardContains(trimmed)
                    || patient.lastName.localizedStandardContains(trimmed)
                )
            },
            sort: \Patient.lastName
        )
    }

    var body: some View {
        PatientDashboardView(
            professional: professional,
            state: store.state,
            namespace: namespace,
            onDelete: onDelete
        )
        .task(id: refreshToken) {
            store.load(from: patients, context: modelContext)
        }
    }

    private var refreshToken: String {
        let patientCount = patients.count
        let patientUpdate = patients.map(\.updatedAt.timeIntervalSince1970).max() ?? 0
        let sessionCount = patients.reduce(0) { $0 + ( $1.sessions?.count ?? 0 ) }
        let sessionUpdate = patients
            .flatMap { $0.sessions ?? [] }
            .map(\.updatedAt.timeIntervalSince1970)
            .max() ?? 0
        let paymentCount = patients
            .flatMap { $0.sessions ?? [] }
            .reduce(0) { $0 + ( $1.payments?.count ?? 0 ) }
        let paymentUpdate = patients
            .flatMap { $0.sessions ?? [] }
            .flatMap { $0.payments ?? [] }
            .map(\.updatedAt.timeIntervalSince1970)
            .max() ?? 0
        let diagnosisCount = patients.reduce(0) { $0 + ($1.activeDiagnoses?.count ?? 0) }
        let diagnosisUpdate = patients
            .flatMap { $0.activeDiagnoses ?? [] }
            .map(\.diagnosedAt.timeIntervalSince1970)
            .max() ?? 0

        return [
            "\(patientCount)",
            "\(patientUpdate)",
            "\(sessionCount)",
            "\(sessionUpdate)",
            "\(paymentCount)",
            "\(paymentUpdate)",
            "\(diagnosisCount)",
            "\(diagnosisUpdate)",
        ].joined(separator: "|")
    }
}

#Preview {
    // Wrapper necesario porque @Namespace no se puede crear inline en #Preview
    struct PreviewWrapper: View {
        @Namespace private var ns
        let professional: Professional

        var body: some View {
            NavigationStack {
                PatientListView(
                    professional: professional,
                    namespace: ns,
                    onAddPatient: {}
                )
            }
        }
    }

    let container = ModelContainer.preview
    let professional = Professional(
        fullName: "Dr. Test",
        licenseNumber: "MN 999",
        specialty: "Psicología"
    )
    container.mainContext.insert(professional)

    let patient = Patient(
        firstName: "Ana",
        lastName: "García",
        professional: professional
    )
    container.mainContext.insert(patient)

    return PreviewWrapper(professional: professional)
        .modelContainer(container)
}

