//
//  PatientDashboardStore.swift
//  Ars Medica Digitalis
//
//  ViewModel del dashboard de pacientes. Construye el estado completo
//  a partir de la lista de pacientes activos y sus snapshots clínicos.
//

import SwiftUI
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class PatientDashboardStore {

    func load(from patients: [Patient], context: ModelContext? = nil) {
        state = Self.buildState(from: patients, context: context)
    }

    private(set) var state = PatientDashboardState.empty

    private static func buildState(from patients: [Patient], context: ModelContext? = nil) -> PatientDashboardState {
        let overallState = PatientDashboardProfiler.signposter.beginInterval("Build Patient Dashboard")
        defer {
            PatientDashboardProfiler.signposter.endInterval("Build Patient Dashboard", overallState)
        }

        let snapshotsState = PatientDashboardProfiler.signposter.beginInterval("Build Snapshot Cache")
        let snapshotCache = ClinicalSnapshotBuilder.buildSnapshots(patients: patients, context: context)
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
        let attentionPatients = rows.filter { $0.sectionKind == .needsAttention }.count
        let patientsWithoutSession30Days = rows.filter { $0.alertKinds.contains(.noSession30Days) }.count
        let stablePatients = rows.filter { $0.sectionKind == .stable }.count
        let averageAdherence = rows.isEmpty ? 0 : (totalAdherence / Double(rows.count))

        PatientDashboardProfiler.signposter.emitEvent(
            "Patient Dashboard Prepared",
            "patients: \(patients.count), sections: \(sections.count), rows: \(rows.count)"
        )

        let summaryWithoutRadar = ClinicalInsightsSummary(
            totalPatients: patients.count,
            title: L10n.tr("patient.dashboard.insights.title"),
            subtitle: L10n.tr("patient.dashboard.insights.analyzed", patients.count),
            criticalPatientsCount: criticalPatients,
            attentionPatientsCount: attentionPatients,
            stablePatientsCount: stablePatients,
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
            ),
            radarModel: .empty
        )

        let stateWithoutRadar = PatientDashboardState(
            summary: summaryWithoutRadar,
            sections: sections
        )
        let radarModel = ClinicalPriorityRadarBuilder.build(from: stateWithoutRadar)

        return PatientDashboardState(
            summary: summaryWithoutRadar.withRadarModel(radarModel),
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

private enum PatientDashboardProfiler {
    static let signposter = OSSignposter(
        logger: Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "ArsMedicaDigitalis",
            category: "PatientDashboard"
        )
    )
}
