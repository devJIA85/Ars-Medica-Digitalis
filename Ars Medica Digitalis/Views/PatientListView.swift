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
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        // Fondo transparente para que el contenido flote sobre el degradado
        // real de la app y el blur de la TabBar funcione correctamente.
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .listStyle(.plain)
    }
}

// MARK: - Fila de paciente

private struct PatientRowView: View {

    let patient: Patient

    var body: some View {
        let summary = rowSummary

        // CardContainer unifica el estilo de celda con PatientDetailView;
        // reemplaza el LinearGradient manual por el sistema nativo Liquid Glass.
        CardContainer(style: .flat) {
            // Jerarquía: avatar (quién) → nombre → subinfo → badges (síntesis)
            HStack(alignment: .center, spacing: 14) {
                PatientAvatarView(
                    photoData: patient.photoData,
                    firstName: patient.firstName,
                    lastName: patient.lastName,
                    genderHint: patient.gender.isEmpty ? patient.biologicalSex : patient.gender,
                    clinicalStatus: patient.clinicalStatus,
                    size: 52
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(patient.fullName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subinfoLine(for: summary))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: AppSpacing.sm) {
                        if let dx = summary.primaryDiagnosisCode {
                            StatusBadge(label: dx, variant: .neutral, systemImage: "stethoscope")
                        }
                        StatusBadge(
                            label: patient.isActive ? "Activo" : "Inactivo",
                            variant: patient.isActive ? .success : .neutral
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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

    /// Condensa sesiones, última fecha y próxima cita en una sola línea de subinfo.
    /// Reemplaza el HStack + infoPills separados para reducir ruido visual.
    private func subinfoLine(for summary: PatientRowSummary) -> String {
        var parts = ["\(summary.sessionCount) sesión\(summary.sessionCount == 1 ? "" : "es")"]
        if let last = summary.latestCompletedSessionDate {
            parts.append("Última: \(last.esDayMonthAbbrev())")
        }
        if let next = summary.nextScheduledSessionDate {
            parts.append("Próxima: \(next.esDayMonthAbbrev())")
        }
        return parts.joined(separator: " · ")
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
