//
//  ClinicalDashboardView.swift
//  Ars Medica Digitalis
//
//  Dashboard clínico global con insights y secciones de pacientes.
//

import SwiftUI
import SwiftData

struct ClinicalDashboardView: View {

    let professional: Professional

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Patient.lastName) private var allPatients: [Patient]
    @State private var filter: ClinicalDashboardFilter = .all
    @State private var viewModel = ClinicalDashboardViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                ClinicalInsightsCard(
                    criticalPatients: viewModel.state.criticalPatients,
                    riskPatients: viewModel.state.riskPatients,
                    averageAdherence: viewModel.state.averageAdherence,
                    patientsWithoutSession30Days: viewModel.state.patientsWithoutSession30Days
                )

                ClinicalDashboardPatientSections(sections: filteredSections)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            .backgroundExtensionEffect()
        }
        .navigationTitle("Dashboard Clínico")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .task(id: refreshToken) {
            viewModel.reload(patients: patients, context: modelContext)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filtrar pacientes", selection: $filter) {
                        ForEach(ClinicalDashboardFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label(filter.title, systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.glass)
            }
        }
        .navigationDestination(for: ClinicalDashboardPatientRoute.self) { route in
            ClinicalDashboardPatientDestinationView(
                patientID: route.patientID,
                professional: professional
            )
        }
    }

    private var filteredSections: [ClinicalDashboardSection] {
        switch filter {
        case .all:
            viewModel.state.sections
        case .highRisk:
            viewModel.state.sections.filter { $0.kind != .stable }
        case .stable:
            viewModel.state.sections.filter { $0.kind == .stable }
        }
    }

    private var patients: [Patient] {
        let professionalID = professional.id
        return allPatients.filter { patient in
            patient.deletedAt == nil && patient.professional?.id == professionalID
        }
    }

    /// Token estable para `.task(id:)`: se invalida solo cuando cambian
    /// pacientes o sus fechas de actualización, evitando recálculos innecesarios.
    private var refreshToken: String {
        patients
            .map { "\($0.id.uuidString)\($0.updatedAt.timeIntervalSince1970)" }
            .sorted()
            .joined()
    }
}

private struct ClinicalDashboardPatientRoute: Hashable {
    let patientID: UUID
}

private enum ClinicalDashboardFilter: String, CaseIterable, Identifiable {
    case all
    case highRisk
    case stable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "Todos"
        case .highRisk:
            "Alto riesgo"
        case .stable:
            "Estable"
        }
    }
}


private struct ClinicalDashboardPatientSections: View {

    let sections: [ClinicalDashboardSection]

    var body: some View {
        if sections.isEmpty {
            ContentUnavailableView(
                "Sin pacientes",
                systemImage: "person.slash",
                description: Text("No hay pacientes que coincidan con este filtro.")
            )
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(sections) { section in
                    CardContainer(style: .elevated) {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Text(section.title)
                                    .font(.headline.weight(.semibold))
                                Spacer()
                                Text("\(section.rows.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: AppSpacing.sm) {
                                ForEach(section.rows) { row in
                                    NavigationLink(
                                        value: ClinicalDashboardPatientRoute(patientID: row.id)
                                    ) {
                                        ClinicalDashboardPatientRow(row: row)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .glassCardEntrance()
                }
            }
        }
    }
}

private struct ClinicalDashboardPatientRow: View {

    let row: ClinicalDashboardPatientRowModel

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            PatientAvatarView(
                photoData: row.photoData,
                firstName: row.firstName,
                lastName: row.lastName,
                genderHint: row.genderHint,
                clinicalStatus: row.clinicalStatus,
                size: 48
            )

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.fullName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: AppSpacing.sm)
                    Text("\(row.riskScore)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Text(row.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        StatusBadge(label: row.riskBadgeLabel, variant: row.riskBadgeVariant, systemImage: "waveform.path.ecg")
                        StatusBadge(label: row.adherenceLabel, variant: .neutral, systemImage: "checkmark.seal")
                        if let diagnosisSummary = row.diagnosisSummary {
                            StatusBadge(label: diagnosisSummary, variant: .neutral, systemImage: "stethoscope")
                        }
                        if row.hasDebt {
                            StatusBadge(label: "Saldo pendiente", variant: .warning, systemImage: "exclamationmark.circle")
                        }
                        if BDISeverityLevel.from(rawSeverity: row.bdiSeverity)?.isHighDepression == true {
                            StatusBadge(label: "BDI alto", variant: .danger, systemImage: "exclamationmark.triangle")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.md)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
        )
    }
}

struct ClinicalDashboardPatientRowModel: Identifiable {
    let id: UUID
    let patientID: UUID
    let photoData: Data?
    let firstName: String
    let lastName: String
    let fullName: String
    let genderHint: String
    let clinicalStatus: String
    let adherence: Double
    let adherenceLabel: String
    let riskScore: Int
    let riskBadgeLabel: String
    let riskBadgeVariant: StatusBadge.Variant
    let diagnosisSummary: String?
    let hasDebt: Bool
    let daysSinceLastSession: Int?
    let subtitle: String
    let sectionKind: ClinicalDashboardSection.Kind
    let bdiSeverity: String?

    init(patient: Patient, snapshot: PatientClinicalSnapshot, insight: PatientInsight) {
        id = patient.id
        patientID = patient.id
        photoData = patient.photoData
        firstName = patient.firstName
        lastName = patient.lastName
        fullName = patient.fullName
        genderHint = patient.gender.isEmpty ? patient.biologicalSex : patient.gender
        clinicalStatus = patient.clinicalStatus
        adherence = insight.adherence
        adherenceLabel = Self.makeAdherenceLabel(from: insight.adherence)
        riskScore = insight.riskScore
        riskBadgeLabel = Self.makeRiskBadgeLabel(for: insight.priorityLevel)
        riskBadgeVariant = Self.makeRiskBadgeVariant(for: insight.priorityLevel)
        diagnosisSummary = snapshot.diagnosisSummary
        hasDebt = snapshot.hasDebt
        daysSinceLastSession = snapshot.daysSinceLastSession
        subtitle = Self.makeSubtitle(snapshot: snapshot)
        sectionKind = Self.makeSectionKind(for: insight.priorityLevel)
        bdiSeverity = snapshot.bdiSeverity
    }

    private static func makeAdherenceLabel(from adherence: Double) -> String {
        let percentage = Int((min(max(adherence, 0), 1) * 100).rounded())
        return "Adherencia \(percentage)%"
    }

    private static func makeRiskBadgeLabel(for priorityLevel: MentalHealthRiskPriorityLevel) -> String {
        switch priorityLevel {
        case .stable:
            "Estable"
        case .moderate:
            "Riesgo medio"
        case .high:
            "Riesgo alto"
        case .critical:
            "Crítico"
        }
    }

    private static func makeRiskBadgeVariant(for priorityLevel: MentalHealthRiskPriorityLevel) -> StatusBadge.Variant {
        switch priorityLevel {
        case .stable:
            .success
        case .moderate:
            .warning
        case .high, .critical:
            .danger
        }
    }

    private static func makeSectionKind(for priorityLevel: MentalHealthRiskPriorityLevel) -> ClinicalDashboardSection.Kind {
        switch priorityLevel {
        case .critical:
            .critical
        case .high, .moderate:
            .highRisk
        case .stable:
            .stable
        }
    }

    private static func makeSubtitle(snapshot: PatientClinicalSnapshot) -> String {
        var parts = ["\(snapshot.sessionCount) sesión\(snapshot.sessionCount == 1 ? "" : "es")"]
        if let lastSessionDate = snapshot.lastSessionDate {
            parts.append("Última: \(lastSessionDate.esDayMonthAbbrev())")
        }
        if let nextSessionDate = snapshot.nextSessionDate {
            parts.append("Próxima: \(nextSessionDate.esDayMonthAbbrev())")
        }
        return parts.joined(separator: " · ")
    }
}

struct ClinicalDashboardSection: Identifiable {

    enum Kind: String, CaseIterable, Identifiable {
        case critical
        case highRisk
        case stable

        static let displayOrder: [Kind] = [.critical, .highRisk, .stable]

        var id: String { rawValue }

        var title: String {
            switch self {
            case .critical:
                "Crítico"
            case .highRisk:
                "Alto riesgo"
            case .stable:
                "Estable"
            }
        }
    }

    let kind: Kind
    let rows: [ClinicalDashboardPatientRowModel]

    var id: Kind { kind }
    var title: String { kind.title }
}

private struct ClinicalDashboardPatientDestinationView: View {

    @Query private var patients: [Patient]

    let patientID: UUID
    let professional: Professional

    init(patientID: UUID, professional: Professional) {
        self.patientID = patientID
        self.professional = professional

        let id = patientID
        _patients = Query(
            filter: #Predicate<Patient> { $0.id == id }
        )
    }

    var body: some View {
        if let patient = patients.first {
            PatientDetailView(patient: patient, professional: professional)
        } else {
            ContentUnavailableView(
                "Paciente no encontrado",
                systemImage: "exclamationmark.triangle"
            )
        }
    }
}

#Preview {
    let container = ModelContainer.preview
    let professional = Professional(
        fullName: "Dra. María López",
        licenseNumber: "MN 54321",
        specialty: "Psicología",
        email: "maria@example.com"
    )
    container.mainContext.insert(professional)

    return NavigationStack {
        ClinicalDashboardView(professional: professional)
    }
    .modelContainer(container)
}
