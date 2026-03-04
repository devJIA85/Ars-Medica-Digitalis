//
//  PatientDashboardView.swift
//  Ars Medica Digitalis
//
//  Dashboard principal de pacientes con métricas y agrupación por riesgo.
//

import SwiftUI
import Observation
import OSLog

@MainActor
@Observable
final class PatientDashboardStore {

    private(set) var state = PatientDashboardState.empty

    func load(from patients: [Patient]) {
        state = Self.buildState(from: patients)
    }

    private static func buildState(from patients: [Patient]) -> PatientDashboardState {
        let overallState = PatientDashboardProfiler.signposter.beginInterval("Build Patient Dashboard")
        defer {
            PatientDashboardProfiler.signposter.endInterval("Build Patient Dashboard", overallState)
        }

        let snapshotsState = PatientDashboardProfiler.signposter.beginInterval("Build Snapshot Cache")
        let snapshotCache = ClinicalSnapshotBuilder.buildSnapshots(patients: patients)
        PatientDashboardProfiler.signposter.endInterval("Build Snapshot Cache", snapshotsState)

        let insightsState = PatientDashboardProfiler.signposter.beginInterval("Build Insight Cache")
        let insightEngine = PatientInsightEngine()
        let insightCache = snapshotCache.reduce(into: [UUID: PatientInsight]()) { partialResult, entry in
            partialResult[entry.key] = insightEngine.buildInsight(snapshot: entry.value)
        }
        PatientDashboardProfiler.signposter.endInterval("Build Insight Cache", insightsState)

        let rowsState = PatientDashboardProfiler.signposter.beginInterval("Build Row Models")
        let rows = patients.compactMap { patient -> PatientDashboardRowModel? in
            guard let snapshot = snapshotCache[patient.id], let insight = insightCache[patient.id] else {
                return nil
            }

            return PatientDashboardRowModel(patient: patient, snapshot: snapshot, insight: insight)
        }
        PatientDashboardProfiler.signposter.endInterval("Build Row Models", rowsState)

        let groupedRows = Dictionary(grouping: rows, by: \.sectionKind)
        let sections = PatientDashboardSection.Kind.displayOrder.compactMap { kind -> PatientDashboardSection? in
            guard let sectionRows = groupedRows[kind], sectionRows.isEmpty == false else {
                return nil
            }

            let sortedRows = sectionRows.sorted { lhs, rhs in
                if lhs.riskScore == rhs.riskScore {
                    return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
                }

                return lhs.riskScore > rhs.riskScore
            }

            return PatientDashboardSection(
                kind: kind,
                rows: sortedRows.enumerated().map { index, row in
                    row.withTransitionDelay(transitionDelay(for: kind, rowIndex: index))
                }
            )
        }

        let totalAdherence = rows.reduce(0) { $0 + $1.adherence }
        let dropoutRiskPatients = rows.filter { $0.alertKinds.contains(.highDropoutRisk) }.count
        let criticalPatients = rows.filter { $0.sectionKind == .critical }.count
        let patientsWithoutSession30Days = rows.filter { $0.alertKinds.contains(.noSession30Days) }.count
        let stablePatients = rows.filter { $0.sectionKind == .stable }.count
        let averageAdherence = rows.isEmpty ? 0 : (totalAdherence / Double(rows.count))

        PatientDashboardProfiler.signposter.emitEvent(
            "Patient Dashboard Prepared",
            "patients: \(patients.count), sections: \(sections.count), rows: \(rows.count)"
        )

        return PatientDashboardState(
            summary: ClinicalInsightsSummary(
                totalPatients: patients.count,
                title: L10n.tr("patient.dashboard.insights.title"),
                subtitle: L10n.tr("patient.dashboard.insights.analyzed", patients.count),
                trends: buildClinicalTrends(
                    rows: rows,
                    totalPatients: patients.count,
                    dropoutRiskPatients: dropoutRiskPatients,
                    patientsWithoutSession30Days: patientsWithoutSession30Days,
                    stablePatients: stablePatients
                ),
                metrics: buildInsightMetrics(
                    criticalPatients: criticalPatients,
                    dropoutRiskPatients: dropoutRiskPatients,
                    averageAdherence: averageAdherence,
                    patientsWithoutSession30Days: patientsWithoutSession30Days
                )
            ),
            sections: sections
        )
    }

    private static func buildInsightMetrics(
        criticalPatients: Int,
        dropoutRiskPatients: Int,
        averageAdherence: Double,
        patientsWithoutSession30Days: Int
    ) -> [InsightMetric] {
        let adherencePercentage = Int((min(max(averageAdherence, 0), 1) * 100).rounded())

        return [
            InsightMetric(
                id: "critical",
                value: "\(criticalPatients)",
                title: L10n.tr("patient.dashboard.metric.critical.title"),
                description: L10n.tr("patient.dashboard.metric.critical.subtitle"),
                systemImage: "cross.case.fill",
                tone: .critical,
                accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.critical.title")): \(criticalPatients)",
                animationDelay: 0
            ),
            InsightMetric(
                id: "dropout",
                value: "\(dropoutRiskPatients)",
                title: L10n.tr("patient.dashboard.metric.dropout.title"),
                description: L10n.tr("patient.dashboard.metric.dropout.subtitle"),
                systemImage: "person.crop.circle.badge.exclamationmark",
                tone: .warning,
                accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.dropout.title")): \(dropoutRiskPatients)",
                animationDelay: 0.03
            ),
            InsightMetric(
                id: "adherence",
                value: "\(adherencePercentage)%",
                title: L10n.tr("patient.dashboard.metric.adherence.title"),
                description: L10n.tr("patient.dashboard.metric.adherence.subtitle"),
                systemImage: "checkmark.seal.fill",
                tone: .positive,
                accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.adherence.title")): \(adherencePercentage)%",
                animationDelay: 0.06
            ),
            InsightMetric(
                id: "sessionGap",
                value: "\(patientsWithoutSession30Days)",
                title: L10n.tr("patient.dashboard.metric.session_gap.title"),
                description: L10n.tr("patient.dashboard.metric.session_gap.subtitle"),
                systemImage: "calendar.badge.exclamationmark",
                tone: .informational,
                accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.session_gap.title")): \(patientsWithoutSession30Days)",
                animationDelay: 0.09
            ),
        ]
    }

    private static func buildClinicalTrends(
        rows: [PatientDashboardRowModel],
        totalPatients: Int,
        dropoutRiskPatients: Int,
        patientsWithoutSession30Days: Int,
        stablePatients: Int
    ) -> [ClinicalTrend] {
        let adherenceDirection = adherenceDirection(from: rows)
        let dropoutDirection = dropoutDirection(
            totalPatients: totalPatients,
            dropoutRiskPatients: dropoutRiskPatients
        )
        let continuityDirection = continuityDirection(
            totalPatients: totalPatients,
            patientsWithoutSession30Days: patientsWithoutSession30Days
        )
        let stabilityDirection = stabilityDirection(
            totalPatients: totalPatients,
            stablePatients: stablePatients
        )

        return [
            ClinicalTrend(
                id: "adherence",
                systemImage: "checkmark.seal.fill",
                displayLabel: "\(adherenceDirection.symbol) \(L10n.tr("patient.dashboard.metric.adherence.title"))",
                tone: trendTone(direction: adherenceDirection, positiveWhenRising: true),
                accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.adherence.title")), \(adherenceDirection.accessibilityLabel)"
            ),
            ClinicalTrend(
                id: "dropout",
                systemImage: "person.crop.circle.badge.exclamationmark",
                displayLabel: "\(dropoutDirection.symbol) \(L10n.tr("patient.dashboard.metric.dropout.title"))",
                tone: trendTone(direction: dropoutDirection, positiveWhenRising: false),
                accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.dropout.title")), \(dropoutDirection.accessibilityLabel)"
            ),
            ClinicalTrend(
                id: "continuity",
                systemImage: "waveform.path.ecg",
                displayLabel: "\(continuityDirection.symbol) \(L10n.tr("patient.dashboard.metric.adherence.subtitle"))",
                tone: trendTone(direction: continuityDirection, positiveWhenRising: true),
                accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.adherence.subtitle")), \(continuityDirection.accessibilityLabel)"
            ),
            ClinicalTrend(
                id: "stability",
                systemImage: "shield.checkered",
                displayLabel: "\(stabilityDirection.symbol) \(L10n.tr("patient.dashboard.clinical_trend.stability"))",
                tone: trendTone(direction: stabilityDirection, positiveWhenRising: true),
                accessibilityLabel: "\(L10n.tr("patient.dashboard.clinical_trend.stability")), \(stabilityDirection.accessibilityLabel)"
            ),
        ]
    }

    private static func adherenceDirection(
        from rows: [PatientDashboardRowModel]
    ) -> ClinicalTrendDirection {
        let score = rows.reduce(0) { partialResult, row in
            partialResult + row.adherenceTrend.score
        }

        if score > 0 {
            return .up
        }

        if score < 0 {
            return .down
        }

        return .flat
    }

    private static func dropoutDirection(
        totalPatients: Int,
        dropoutRiskPatients: Int
    ) -> ClinicalTrendDirection {
        guard totalPatients > 0 else { return .flat }
        let ratio = Double(dropoutRiskPatients) / Double(totalPatients)

        if ratio <= 0.2 {
            return .down
        }

        if ratio >= 0.4 {
            return .up
        }

        return .flat
    }

    private static func continuityDirection(
        totalPatients: Int,
        patientsWithoutSession30Days: Int
    ) -> ClinicalTrendDirection {
        guard totalPatients > 0 else { return .flat }
        let ratio = Double(patientsWithoutSession30Days) / Double(totalPatients)

        if ratio <= 0.15 {
            return .up
        }

        if ratio >= 0.3 {
            return .down
        }

        return .flat
    }

    private static func stabilityDirection(
        totalPatients: Int,
        stablePatients: Int
    ) -> ClinicalTrendDirection {
        guard totalPatients > 0 else { return .flat }
        let ratio = Double(stablePatients) / Double(totalPatients)

        if ratio >= 0.6 {
            return .up
        }

        if ratio <= 0.3 {
            return .down
        }

        return .flat
    }

    private static func trendTone(
        direction: ClinicalTrendDirection,
        positiveWhenRising: Bool
    ) -> ClinicalTrendTone {
        switch direction {
        case .flat:
            return .neutral
        case .up:
            return positiveWhenRising ? .positive : .caution
        case .down:
            return positiveWhenRising ? .caution : .positive
        }
    }

    private static func transitionDelay(
        for kind: PatientDashboardSection.Kind,
        rowIndex: Int
    ) -> Double {
        let sectionOffset: Double
        switch kind {
        case .critical:
            sectionOffset = 0
        case .needsAttention:
            sectionOffset = 0.04
        case .stable:
            sectionOffset = 0.08
        }

        return min(sectionOffset + (Double(rowIndex) * 0.02), 0.26)
    }
}

struct PatientDashboardView: View {

    let state: PatientDashboardState
    let namespace: Namespace.ID
    let onDelete: (Patient) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xl) {
                if state.hasPatients {
                    ClinicalInsightsHeader(summary: state.summary)

                    ForEach(state.sections) { section in
                        PatientRiskSection(section: section, namespace: namespace, onDelete: onDelete)
                    }
                } else {
                    ContentUnavailableView(
                        L10n.tr("patient.dashboard.empty.title"),
                        systemImage: "person.2.slash",
                        description: Text(L10n.tr("patient.dashboard.empty.subtitle"))
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
            .backgroundExtensionEffect()
        }
        .background(backgroundGradient)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color(uiColor: .secondarySystemGroupedBackground),
                Color(uiColor: .systemGroupedBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.teal.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 26)
                .offset(x: 70, y: -30)
        }
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Color.blue.opacity(0.06))
                .frame(width: 200, height: 200)
                .blur(radius: 34)
                .offset(x: -40, y: 40)
        }
        .ignoresSafeArea()
    }
}

struct ClinicalInsightsSummary: Equatable {
    let totalPatients: Int
    let title: String
    let subtitle: String
    let trends: [ClinicalTrend]
    let metrics: [InsightMetric]
}

struct PatientDashboardState: Equatable {
    let summary: ClinicalInsightsSummary
    let sections: [PatientDashboardSection]

    var hasPatients: Bool {
        summary.totalPatients > 0
    }

    static let empty = PatientDashboardState(
        summary: ClinicalInsightsSummary(
            totalPatients: 0,
            title: L10n.tr("patient.dashboard.insights.title"),
            subtitle: L10n.tr("patient.dashboard.insights.analyzed", 0),
            trends: [],
            metrics: []
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

    fileprivate var score: Int {
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
        let closedSessions = (patient.sessions ?? [])
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
            && lhs.transitionDelay == rhs.transitionDelay
    }
}

private enum PatientDashboardProfiler {
    static let signposter = OSSignposter(
        logger: Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "ArsMedicaDigitalis",
            category: "PatientDashboard"
        )
    )
}
