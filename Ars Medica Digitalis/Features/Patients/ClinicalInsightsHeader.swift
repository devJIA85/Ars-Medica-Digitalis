//
//  ClinicalInsightsHeader.swift
//  Ars Medica Digitalis
//
//  Encabezado de inteligencia clínica con trends y grilla de métricas.
//

import SwiftUI

struct ClinicalInsightsHeader: View {

    let summary: ClinicalInsightsSummary
    let selectedRadarBucket: ClinicalPriorityBucket?
    let onSelectRadarBucket: (ClinicalPriorityBucket?) -> Void

    init(
        summary: ClinicalInsightsSummary,
        selectedRadarBucket: ClinicalPriorityBucket? = nil,
        onSelectRadarBucket: @escaping (ClinicalPriorityBucket?) -> Void = { _ in }
    ) {
        self.summary = summary
        self.selectedRadarBucket = selectedRadarBucket
        self.onSelectRadarBucket = onSelectRadarBucket
    }

    init(
        criticalPatients: Int,
        riskPatients: Int,
        averageAdherence: Double,
        patientsWithoutSession30Days: Int,
        totalPatients: Int = 0
    ) {
        let analyzedCount = max(totalPatients, criticalPatients + riskPatients)
        let adherencePercentage = Int((min(max(averageAdherence, 0), 1) * 100).rounded())
        let attentionPatients = max(riskPatients - criticalPatients, 0)
        let stablePatients = max(analyzedCount - criticalPatients - attentionPatients, 0)
        let radarModel = ClinicalPriorityRadarModel(
            totalCount: analyzedCount,
            criticalCount: criticalPatients,
            attentionCount: attentionPatients,
            stableCount: stablePatients
        )

        self.summary = ClinicalInsightsSummary(
            totalPatients: analyzedCount,
            title: L10n.tr("patient.dashboard.insights.title"),
            subtitle: analyzedCount > 0
                ? L10n.tr("patient.dashboard.insights.analyzed", analyzedCount)
                : L10n.tr("patient.dashboard.insights.subtitle"),
            criticalPatientsCount: criticalPatients,
            attentionPatientsCount: attentionPatients,
            stablePatientsCount: stablePatients,
            trends: [
                ClinicalTrend(
                    id: "adherence",
                    systemImage: "checkmark.seal.fill",
                    displayLabel: "\(ClinicalTrendDirection.flat.symbol) \(L10n.tr("patient.dashboard.metric.adherence.title"))",
                    tone: .neutral,
                    accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.adherence.title")), \(ClinicalTrendDirection.flat.accessibilityLabel)"
                ),
                ClinicalTrend(
                    id: "dropout",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    displayLabel: "\(ClinicalTrendDirection.flat.symbol) \(L10n.tr("patient.dashboard.metric.dropout.title"))",
                    tone: .neutral,
                    accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.dropout.title")), \(ClinicalTrendDirection.flat.accessibilityLabel)"
                ),
                ClinicalTrend(
                    id: "continuity",
                    systemImage: "waveform.path.ecg",
                    displayLabel: "\(ClinicalTrendDirection.flat.symbol) \(L10n.tr("patient.dashboard.metric.adherence.subtitle"))",
                    tone: .neutral,
                    accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.adherence.subtitle")), \(ClinicalTrendDirection.flat.accessibilityLabel)"
                ),
                ClinicalTrend(
                    id: "stability",
                    systemImage: "shield.checkered",
                    displayLabel: "\(ClinicalTrendDirection.flat.symbol) \(L10n.tr("patient.dashboard.clinical_trend.stability"))",
                    tone: .neutral,
                    accessibilityLabel: "\(L10n.tr("patient.dashboard.clinical_trend.stability")), \(ClinicalTrendDirection.flat.accessibilityLabel)"
                ),
            ],
            metrics: [
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
                    value: "\(riskPatients)",
                    title: L10n.tr("patient.dashboard.metric.dropout.title"),
                    description: L10n.tr("patient.dashboard.metric.dropout.subtitle"),
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    tone: .warning,
                    accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.dropout.title")): \(riskPatients)",
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
            ],
            radarModel: radarModel
        )
        self.selectedRadarBucket = nil
        self.onSelectRadarBucket = { _ in }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(summary.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(summary.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ClinicalPriorityRadar(
                model: summary.radarModel,
                selectedBucket: selectedRadarBucket,
                onSelectBucket: onSelectRadarBucket
            )

            ClinicalTrendBar(trends: summary.trends)
            InsightMetricsGrid(metrics: summary.metrics)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, y: 10)
        .glassCardEntrance()
    }
}
