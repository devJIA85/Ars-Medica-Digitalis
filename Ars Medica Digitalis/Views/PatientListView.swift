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

    /// Texto de búsqueda inyectado desde el Tab(role: .search) del TabView.
    var externalSearchText: String? = nil

    @State private var searchText: String = ""
    @State private var showInactive: Bool = false

    /// Usa el texto externo (del search tab) si existe, sino el local.
    private var effectiveSearchText: String {
        externalSearchText ?? searchText
    }

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        let dashboard = PatientFilteredList(
            searchText: effectiveSearchText,
            showInactive: showInactive,
            professional: professional,
            namespace: namespace
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
    let namespace: Namespace.ID

    init(
        searchText: String,
        showInactive: Bool,
        professional: Professional,
        namespace: Namespace.ID
    ) {
        self.professional = professional
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
            namespace: namespace
        )
        .task(id: refreshToken) {
            store.load(from: patients, context: modelContext)
        }
    }

    private var refreshToken: String {
        let patientCount = patients.count
        let patientUpdate = patients.map(\.updatedAt.timeIntervalSince1970).max() ?? 0
        let sessionCount = patients.reduce(0) { $0 + $1.sessions.count }
        let sessionUpdate = patients
            .flatMap(\.sessions)
            .map(\.updatedAt.timeIntervalSince1970)
            .max() ?? 0
        let paymentCount = patients
            .flatMap(\.sessions)
            .reduce(0) { $0 + $1.payments.count }
        let paymentUpdate = patients
            .flatMap(\.sessions)
            .flatMap(\.payments)
            .map(\.updatedAt.timeIntervalSince1970)
            .max() ?? 0
        let diagnosisCount = patients.reduce(0) { $0 + $1.activeDiagnoses.count }
        let diagnosisUpdate = patients
            .flatMap(\.activeDiagnoses)
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
