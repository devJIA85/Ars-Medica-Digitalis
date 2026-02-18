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

    @Environment(\.modelContext) private var modelContext

    @State private var searchText: String = ""
    @State private var showInactive: Bool = false
    @State private var showingNewPatient: Bool = false
    @State private var patientToDelete: Patient? = nil

    var body: some View {
        PatientFilteredList(
            searchText: searchText,
            showInactive: showInactive,
            professional: professional,
            onDelete: { patient in
                patientToDelete = patient
            }
        )
        .searchable(text: $searchText, prompt: "Buscar paciente")
        .navigationTitle(showInactive ? "Pacientes Inactivos" : "Pacientes")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showInactive.toggle()
                } label: {
                    Label(
                        showInactive ? "Ver Activos" : "Ver Inactivos",
                        systemImage: showInactive ? "person.fill" : "person.slash"
                    )
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileEditView(professional: professional)
                } label: {
                    Label("Perfil", systemImage: "person.circle")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button {
                    showingNewPatient = true
                } label: {
                    Label("Nuevo Paciente", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewPatient) {
            NavigationStack {
                PatientFormView(professional: professional)
            }
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
    }
}

// MARK: - Sublista filtrada con #Predicate

/// Vista interna que ejecuta el @Query con filtros dinámicos.
/// Separada porque #Predicate necesita ser construido antes del body
/// y @Query no acepta parámetros dinámicos inline.
private struct PatientFilteredList: View {

    @Query private var patients: [Patient]

    let onDelete: (Patient) -> Void

    init(
        searchText: String,
        showInactive: Bool,
        professional: Professional,
        onDelete: @escaping (Patient) -> Void
    ) {
        self.onDelete = onDelete

        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        // #Predicate filtra por estado activo/inactivo y texto de búsqueda.
        // Todo se resuelve localmente en SwiftData, sin llamadas de red.
        if trimmed.isEmpty {
            if showInactive {
                _patients = Query(
                    filter: #Predicate<Patient> { patient in
                        patient.deletedAt != nil
                    },
                    sort: \Patient.lastName
                )
            } else {
                _patients = Query(
                    filter: #Predicate<Patient> { patient in
                        patient.deletedAt == nil
                    },
                    sort: \Patient.lastName
                )
            }
        } else {
            if showInactive {
                _patients = Query(
                    filter: #Predicate<Patient> { patient in
                        patient.deletedAt != nil
                        && (patient.firstName.localizedStandardContains(trimmed)
                            || patient.lastName.localizedStandardContains(trimmed))
                    },
                    sort: \Patient.lastName
                )
            } else {
                _patients = Query(
                    filter: #Predicate<Patient> { patient in
                        patient.deletedAt == nil
                        && (patient.firstName.localizedStandardContains(trimmed)
                            || patient.lastName.localizedStandardContains(trimmed))
                    },
                    sort: \Patient.lastName
                )
            }
        }
    }

    var body: some View {
        List {
            if patients.isEmpty {
                ContentUnavailableView(
                    "Sin pacientes",
                    systemImage: "person.slash",
                    description: Text("No se encontraron pacientes con estos criterios.")
                )
            } else {
                ForEach(patients) { patient in
                    NavigationLink(value: patient.id) {
                        PatientRowView(patient: patient)
                    }
                    .swipeActions(edge: .trailing) {
                        if patient.isActive {
                            Button("Baja", role: .destructive) {
                                onDelete(patient)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Fila de paciente

private struct PatientRowView: View {

    let patient: Patient

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(patient.fullName)
                    .font(.body)
                    .fontWeight(.medium)

                if !patient.isActive, let deletedAt = patient.deletedAt {
                    Text("Baja: \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }

            let sessionCount = patient.sessions?.count ?? 0
            if sessionCount > 0 {
                Text("\(sessionCount) sesión\(sessionCount == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Professional.self, Patient.self, Session.self, Diagnosis.self, Attachment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
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

    return NavigationStack {
        PatientListView(professional: professional)
    }
    .modelContainer(container)
}
