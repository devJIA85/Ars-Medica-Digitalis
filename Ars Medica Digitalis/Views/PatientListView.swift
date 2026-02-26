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

    @Environment(\.modelContext) private var modelContext

    @State private var searchText: String = ""
    @State private var showInactive: Bool = false
    @State private var patientToDelete: Patient? = nil

    var body: some View {
        PatientFilteredList(
            searchText: searchText,
            showInactive: showInactive,
            professional: professional,
            namespace: namespace,
            onDelete: { patient in
                patientToDelete = patient
            }
        )
        .searchable(text: $searchText, placement: .automatic, prompt: "Buscar paciente")
        .searchToolbarBehavior(.minimize)
        .navigationTitle(showInactive ? "Pacientes Inactivos" : "Pacientes")
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
                    Text("+ Nuevo")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Agregar nuevo paciente")
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileEditView(professional: professional)
                } label: {
                    Label("Perfil", systemImage: "person.crop.circle")
                }
            }

            DefaultToolbarItem(kind: .search, placement: .topBarTrailing)

            // El CTA principal vive en el top bar, junto a búsqueda y perfil.
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
    let namespace: Namespace.ID

    init(
        searchText: String,
        showInactive: Bool,
        professional: Professional,
        namespace: Namespace.ID,
        onDelete: @escaping (Patient) -> Void
    ) {
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
        List {
            if patients.isEmpty {
                ContentUnavailableView(
                    "Sin pacientes",
                    systemImage: "person.slash",
                    description: Text("No se encontraron pacientes con estos criterios.")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(patients) { patient in
                    NavigationLink(value: patient.id) {
                        PatientRowView(patient: patient)
                    }
                    // Fuente visual para la transición zoom al navegar al detalle
                    .matchedTransitionSource(id: patient.id, in: namespace)
                    .swipeActions(edge: .trailing) {
                        if patient.isActive {
                            Button("Baja", role: .destructive) {
                                onDelete(patient)
                            }
                        }
                    }
                    // Eliminar separadores y fondo del sistema para
                    // que las cards con material floten sobre el fondo limpio
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
        }
        // Eliminamos modificadores que interfieren con el material translúcido de la TabBar
        .listStyle(.plain)
    }
}

// MARK: - Fila de paciente

private struct PatientRowView: View {

    let patient: Patient

    var body: some View {
        let summary = rowSummary

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Avatar circular con iniciales (o foto) y anillo de estado clínico
                PatientAvatarView(
                    photoData: patient.photoData,
                    firstName: patient.firstName,
                    lastName: patient.lastName,
                    genderHint: patient.gender.isEmpty ? patient.biologicalSex : patient.gender,
                    clinicalStatus: patient.clinicalStatus,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(patient.fullName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 4) {
                        Text("\(summary.sessionCount) sesión\(summary.sessionCount == 1 ? "" : "es")")
                        if let latestCompletedSessionDate = summary.latestCompletedSessionDate {
                            Text("· Última: \(latestCompletedSessionDate.esDayMonthAbbrev())")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                statusBadge
            }

            HStack(spacing: 8) {
                infoPill(
                    title: "Dx",
                    value: summary.primaryDiagnosisCode ?? "Sin Dx",
                    icon: "stethoscope"
                )

                if let nextScheduledSessionDate = summary.nextScheduledSessionDate {
                    infoPill(
                        title: "Próxima",
                        value: nextScheduledSessionDate.esDayMonthAbbrev(),
                        icon: "calendar.badge.clock"
                    )
                }
            }
            .lineLimit(1)
        }
        // Card clínica con estilo "liquid glass":
        // material translúcido, borde de luz y sombra suave.
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.white.opacity(0.25), radius: 1, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
        )
    }

    private var rowSummary: PatientRowSummary {
        let sessions = patient.sessions ?? []
        let today = Calendar.current.startOfDay(for: Date())

        var latestCompletedSessionDate: Date?
        var latestCompletedDiagnoses: [Diagnosis]?
        var nextScheduledSessionDate: Date?

        for session in sessions {
            if session.sessionStatusValue == .completada {
                if let currentLatest = latestCompletedSessionDate {
                    if session.sessionDate > currentLatest {
                        latestCompletedSessionDate = session.sessionDate
                        latestCompletedDiagnoses = session.diagnoses
                    }
                } else {
                    latestCompletedSessionDate = session.sessionDate
                    latestCompletedDiagnoses = session.diagnoses
                }
            }

            if session.sessionStatusValue == .programada,
                session.sessionDate >= today {
                if let currentNext = nextScheduledSessionDate {
                    if session.sessionDate < currentNext {
                        nextScheduledSessionDate = session.sessionDate
                    }
                } else {
                    nextScheduledSessionDate = session.sessionDate
                }
            }
        }

        let primaryDiagnosisCode =
            diagnosisCode(from: patient.activeDiagnoses)
            ?? diagnosisCode(from: latestCompletedDiagnoses)

        return PatientRowSummary(
            sessionCount: sessions.count,
            latestCompletedSessionDate: latestCompletedSessionDate,
            nextScheduledSessionDate: nextScheduledSessionDate,
            primaryDiagnosisCode: primaryDiagnosisCode
        )
    }

    private func diagnosisCode(from diagnoses: [Diagnosis]?) -> String? {
        let list = diagnoses ?? []
        guard !list.isEmpty else { return nil }

        let preferred = list.first {
            $0.diagnosisType.localizedCaseInsensitiveCompare("principal") == .orderedSame
        } ?? list.first

        let rawCode = preferred?.icdCode.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return rawCode.isEmpty ? nil : rawCode
    }

    private struct PatientRowSummary {
        let sessionCount: Int
        let latestCompletedSessionDate: Date?
        let nextScheduledSessionDate: Date?
        let primaryDiagnosisCode: String?
    }

    @ViewBuilder
    private func infoPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(title):")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 0.8)
                )
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(patient.isActive ? Color.green : Color.gray)
                .frame(width: 7, height: 7)

            Text(patient.isActive ? "Activo" : "Inactivo")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(patient.isActive ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.65), lineWidth: 0.8)
                )
        )
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
