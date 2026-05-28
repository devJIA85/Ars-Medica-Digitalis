//
//  PatientDashboardModels.swift
//  Ars Medica Digitalis
//
//  Tipos de estado y modelo de presentación del dashboard de pacientes.
//  Separados de la vista y el store para facilitar tests unitarios.
//

import SwiftUI

struct ClinicalInsightsSummary: Equatable {
    let totalPatients: Int
    let title: String
    let subtitle: String
    let criticalPatientsCount: Int
    let attentionPatientsCount: Int
    let stablePatientsCount: Int
    let trends: [ClinicalTrend]
    let metrics: [InsightMetric]
    let radarModel: ClinicalPriorityRadarModel

    func withRadarModel(_ radarModel: ClinicalPriorityRadarModel) -> ClinicalInsightsSummary {
        ClinicalInsightsSummary(
            totalPatients: totalPatients,
            title: title,
            subtitle: subtitle,
            criticalPatientsCount: criticalPatientsCount,
            attentionPatientsCount: attentionPatientsCount,
            stablePatientsCount: stablePatientsCount,
            trends: trends,
            metrics: metrics,
            radarModel: radarModel
        )
    }
}

struct PatientDashboardState: Equatable {
    let summary: ClinicalInsightsSummary
    let sections: [PatientDashboardSection]

    var hasPatients: Bool {
        summary.totalPatients > 0
    }

    /// All patient rows sorted alphabetically by last name for the Pacientes tab.
    var alphabeticalRows: [PatientDashboardRowModel] {
        sections
            .flatMap(\.rows)
            .sorted { $0.lastName.localizedCaseInsensitiveCompare($1.lastName) == .orderedAscending }
    }

    static let empty = PatientDashboardState(
        summary: ClinicalInsightsSummary(
            totalPatients: 0,
            title: L10n.tr("patient.dashboard.insights.title"),
            subtitle: L10n.tr("patient.dashboard.insights.analyzed", 0),
            criticalPatientsCount: 0,
            attentionPatientsCount: 0,
            stablePatientsCount: 0,
            trends: [],
            metrics: [],
            radarModel: .empty
        ),
        sections: []
    )
}

struct PatientDashboardSection: Identifiable, Equatable {

    enum Kind: String, CaseIterable, Identifiable {
        case critical
        case needsAttention
        case stable

        static let displayOrder: [Kind] = [.critical, .needsAttention, .stable]

        var id: String { rawValue }

        var title: String {
            switch self {
            case .critical:
                L10n.tr("patient.dashboard.section.critical.title")
            case .needsAttention:
                L10n.tr("patient.dashboard.section.attention.title")
            case .stable:
                L10n.tr("patient.dashboard.section.stable.title")
            }
        }

        var subtitle: String {
            switch self {
            case .critical:
                L10n.tr("patient.dashboard.section.critical.subtitle")
            case .needsAttention:
                L10n.tr("patient.dashboard.section.attention.subtitle")
            case .stable:
                L10n.tr("patient.dashboard.section.stable.subtitle")
            }
        }
    }

    let kind: Kind
    let rows: [PatientDashboardRowModel]

    var id: Kind { kind }
    var title: String { kind.title }
    var subtitle: String { kind.subtitle }
}

enum PatientAdherenceTrend: Equatable {
    case improving
    case worsening
    case steady

    var symbolName: String {
        switch self {
        case .improving:
            "arrow.up.right"
        case .worsening:
            "arrow.down.right"
        case .steady:
            "minus"
        }
    }

    var tint: Color {
        switch self {
        case .improving:
            .green
        case .worsening:
            .red
        case .steady:
            .secondary
        }
    }

    var shortLabel: String {
        switch self {
        case .improving:
            L10n.tr("patient.dashboard.trend.improving")
        case .worsening:
            L10n.tr("patient.dashboard.trend.worsening")
        case .steady:
            L10n.tr("patient.dashboard.trend.steady")
        }
    }

    var accessibilityLabel: String {
        shortLabel
    }

    // Usado por PatientDashboardStore.adherenceDirection(from:) para calcular
    // la dirección de tendencia agregada del panel.
    var score: Int {
        switch self {
        case .improving:
            1
        case .worsening:
            -1
        case .steady:
            0
        }
    }
}

struct PatientDashboardRowModel: Identifiable, Equatable {
    let patient: Patient
    let id: UUID
    let photoData: Data?
    let firstName: String
    let lastName: String
    let fullName: String
    let genderHint: String
    let clinicalStatus: String
    let isActive: Bool
    let diagnosisSummary: String?
    let hasDebt: Bool
    let adherence: Double
    let adherencePercentage: Int
    let adherenceTrend: PatientAdherenceTrend
    let riskScore: Int
    let priorityLevel: MentalHealthRiskPriorityLevel
    let urgency: MentalHealthRiskUrgency
    let alertKinds: Set<PatientAlert.Kind>
    let daysSinceLastSession: Int?
    let sessionSummary: String
    let bdiSeverity: String?
    let transitionDelay: Double

    var sectionKind: PatientDashboardSection.Kind {
        switch priorityLevel {
        case .critical:
            .critical
        case .high, .moderate:
            .needsAttention
        case .stable:
            .stable
        }
    }

    var adherenceLabel: String {
        L10n.tr("patient.dashboard.adherence.format", adherencePercentage)
    }

    var riskBadgeLabel: String {
        switch priorityLevel {
        case .stable:
            L10n.tr("patient.dashboard.badge.risk.stable")
        case .moderate:
            L10n.tr("patient.dashboard.badge.risk.moderate")
        case .high:
            L10n.tr("patient.dashboard.badge.risk.high")
        case .critical:
            L10n.tr("patient.dashboard.badge.risk.critical")
        }
    }

    var riskBadgeVariant: StatusBadge.Variant {
        switch priorityLevel {
        case .stable:
            .success
        case .moderate, .high:
            .warning
        case .critical:
            .danger
        }
    }

    var riskRingTint: Color {
        switch priorityLevel {
        case .stable:
            .green
        case .moderate, .high:
            .orange
        case .critical:
            .red
        }
    }

    var activeBadgeLabel: String {
        isActive ? L10n.tr("patient.dashboard.badge.active") : L10n.tr("patient.dashboard.badge.inactive")
    }

    var activeBadgeVariant: StatusBadge.Variant {
        isActive ? .success : .neutral
    }

    init(
        patient: Patient,
        snapshot: PatientClinicalSnapshot,
        insight: PatientInsight
    ) {
        self.patient = patient
        id = patient.id
        photoData = patient.photoData
        firstName = patient.firstName
        lastName = patient.lastName
        fullName = patient.fullName
        genderHint = patient.gender.isEmpty ? patient.biologicalSex : patient.gender
        clinicalStatus = patient.clinicalStatus
        isActive = patient.isActive
        diagnosisSummary = snapshot.diagnosisSummary
        hasDebt = snapshot.hasDebt
        adherence = insight.adherence
        adherencePercentage = Int((min(max(insight.adherence, 0), 1) * 100).rounded())
        adherenceTrend = Self.makeAdherenceTrend(from: patient)
        riskScore = insight.riskScore
        priorityLevel = insight.priorityLevel
        urgency = insight.urgency
        alertKinds = Set(insight.alerts.map(\.kind))
        daysSinceLastSession = snapshot.daysSinceLastSession
        sessionSummary = Self.makeSessionSummary(snapshot: snapshot)
        bdiSeverity = snapshot.bdiSeverity
        transitionDelay = 0
    }

    private init(
        patient: Patient,
        id: UUID,
        photoData: Data?,
        firstName: String,
        lastName: String,
        fullName: String,
        genderHint: String,
        clinicalStatus: String,
        isActive: Bool,
        diagnosisSummary: String?,
        hasDebt: Bool,
        adherence: Double,
        adherencePercentage: Int,
        adherenceTrend: PatientAdherenceTrend,
        riskScore: Int,
        priorityLevel: MentalHealthRiskPriorityLevel,
        urgency: MentalHealthRiskUrgency,
        alertKinds: Set<PatientAlert.Kind>,
        daysSinceLastSession: Int?,
        sessionSummary: String,
        bdiSeverity: String?,
        transitionDelay: Double
    ) {
        self.patient = patient
        self.id = id
        self.photoData = photoData
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.genderHint = genderHint
        self.clinicalStatus = clinicalStatus
        self.isActive = isActive
        self.diagnosisSummary = diagnosisSummary
        self.hasDebt = hasDebt
        self.adherence = adherence
        self.adherencePercentage = adherencePercentage
        self.adherenceTrend = adherenceTrend
        self.riskScore = riskScore
        self.priorityLevel = priorityLevel
        self.urgency = urgency
        self.alertKinds = alertKinds
        self.daysSinceLastSession = daysSinceLastSession
        self.sessionSummary = sessionSummary
        self.bdiSeverity = bdiSeverity
        self.transitionDelay = transitionDelay
    }

    func withTransitionDelay(_ transitionDelay: Double) -> PatientDashboardRowModel {
        PatientDashboardRowModel(
            patient: patient,
            id: id,
            photoData: photoData,
            firstName: firstName,
            lastName: lastName,
            fullName: fullName,
            genderHint: genderHint,
            clinicalStatus: clinicalStatus,
            isActive: isActive,
            diagnosisSummary: diagnosisSummary,
            hasDebt: hasDebt,
            adherence: adherence,
            adherencePercentage: adherencePercentage,
            adherenceTrend: adherenceTrend,
            riskScore: riskScore,
            priorityLevel: priorityLevel,
            urgency: urgency,
            alertKinds: alertKinds,
            daysSinceLastSession: daysSinceLastSession,
            sessionSummary: sessionSummary,
            bdiSeverity: bdiSeverity,
            transitionDelay: transitionDelay
        )
    }

    private static func makeSessionSummary(snapshot: PatientClinicalSnapshot) -> String {
        var parts = ["\(snapshot.sessionCount) sesión\(snapshot.sessionCount == 1 ? "" : "es")"]

        if let lastSessionDate = snapshot.lastSessionDate {
            parts.append("Última \(lastSessionDate.esDayMonthAbbrev())")
        }

        if let nextSessionDate = snapshot.nextSessionDate {
            parts.append("Próxima \(nextSessionDate.esDayMonthAbbrev())")
        } else if let daysSinceLastSession = snapshot.daysSinceLastSession, daysSinceLastSession >= 30 {
            parts.append("\(daysSinceLastSession)d sin sesión")
        }

        return parts.joined(separator: " · ")
    }

    private static func makeAdherenceTrend(from patient: Patient) -> PatientAdherenceTrend {
        let closedSessions = patient.sessions
            .filter { session in
                let status = session.sessionStatusValue
                return status == .completada || status == .cancelada
            }
            .sorted { $0.sessionDate > $1.sessionDate }

        guard closedSessions.count >= 2 else {
            return .steady
        }

        let windowSize = min(max(closedSessions.count / 2, 1), 3)
        let recentWindow = Array(closedSessions.prefix(windowSize))
        let previousWindow = Array(closedSessions.dropFirst(windowSize).prefix(windowSize))

        guard previousWindow.isEmpty == false else {
            return .steady
        }

        let delta = adherenceRatio(for: recentWindow) - adherenceRatio(for: previousWindow)

        if delta > 0.05 {
            return .improving
        }

        if delta < -0.05 {
            return .worsening
        }

        return .steady
    }

    private static func adherenceRatio(for sessions: [Session]) -> Double {
        let completed = sessions.filter { $0.sessionStatusValue == .completada }.count
        let cancelled = sessions.filter { $0.sessionStatusValue == .cancelada }.count
        let total = completed + cancelled

        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    static func == (lhs: PatientDashboardRowModel, rhs: PatientDashboardRowModel) -> Bool {
        lhs.id == rhs.id
            && lhs.photoData == rhs.photoData
            && lhs.firstName == rhs.firstName
            && lhs.lastName == rhs.lastName
            && lhs.fullName == rhs.fullName
            && lhs.genderHint == rhs.genderHint
            && lhs.clinicalStatus == rhs.clinicalStatus
            && lhs.isActive == rhs.isActive
            && lhs.diagnosisSummary == rhs.diagnosisSummary
            && lhs.hasDebt == rhs.hasDebt
            && lhs.adherence == rhs.adherence
            && lhs.adherencePercentage == rhs.adherencePercentage
            && lhs.adherenceTrend == rhs.adherenceTrend
            && lhs.riskScore == rhs.riskScore
            && lhs.priorityLevel == rhs.priorityLevel
            && lhs.urgency == rhs.urgency
            && lhs.alertKinds == rhs.alertKinds
            && lhs.daysSinceLastSession == rhs.daysSinceLastSession
            && lhs.sessionSummary == rhs.sessionSummary
            && lhs.bdiSeverity == rhs.bdiSeverity
            && lhs.transitionDelay == rhs.transitionDelay
    }
}
