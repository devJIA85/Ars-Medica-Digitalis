//
//  ClinicalInsightsHeader.swift
//  Ars Medica Digitalis
//
//  Encabezado de inteligencia clínica con trends y grilla de métricas.
//

import SwiftUI

struct ClinicalInsightsHeader: View {

    let summary: ClinicalInsightsSummary
    let isCollapsed: Bool
    let selectedRadarBucket: ClinicalPriorityBucket?
    let onSelectRadarBucket: (ClinicalPriorityBucket?) -> Void
    let onToggleCollapse: () -> Void

    init(
        summary: ClinicalInsightsSummary,
        isCollapsed: Bool = false,
        selectedRadarBucket: ClinicalPriorityBucket? = nil,
        onSelectRadarBucket: @escaping (ClinicalPriorityBucket?) -> Void = { _ in },
        onToggleCollapse: @escaping () -> Void = {}
    ) {
        self.summary = summary
        self.isCollapsed = isCollapsed
        self.selectedRadarBucket = selectedRadarBucket
        self.onSelectRadarBucket = onSelectRadarBucket
        self.onToggleCollapse = onToggleCollapse
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
        self.isCollapsed = false
        self.selectedRadarBucket = nil
        self.onSelectRadarBucket = { _ in }
        self.onToggleCollapse = {}
    }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedLayout
            } else {
                expandedLayout
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, isCollapsed ? 10 : AppSpacing.md)
        .frame(minHeight: isCollapsed ? 60 : nil)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, y: 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isCollapsed)
        .glassCardEntrance()
    }

    private var expandedLayout: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            headerRow(titleFont: .title3.weight(.semibold), subtitleFont: .footnote)

            ClinicalPriorityRadar(
                model: summary.radarModel,
                size: .large,
                selectedBucket: selectedRadarBucket,
                onSelectBucket: onSelectRadarBucket
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(.opacity.combined(with: .scale(scale: 1.04, anchor: .top)))

            ClinicalTrendBar(trends: summary.trends)
                .transition(.opacity.combined(with: .move(edge: .top)))

            InsightMetricsGrid(metrics: summary.metrics, isCompact: true)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var collapsedLayout: some View {
        HStack(spacing: 12) {
            MiniClinicalRadarView(
                model: summary.radarModel,
                selectedBucket: selectedRadarBucket,
                onSelectBucket: onSelectRadarBucket
            )
            .transition(.opacity.combined(with: .scale(scale: 0.86, anchor: .topLeading)))

            titleBlock(titleFont: .headline.weight(.semibold), subtitleFont: .caption)

            Spacer(minLength: 0)

            collapseToggleButton
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func headerRow(titleFont: Font, subtitleFont: Font) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            titleBlock(titleFont: titleFont, subtitleFont: subtitleFont)
            Spacer(minLength: 0)
            collapseToggleButton
        }
    }

    private func titleBlock(titleFont: Font, subtitleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.title)
                .font(titleFont)
                .foregroundStyle(.primary)
                .accessibilityLabel("\(summary.title), \(insightsStateAccessibilityText)")

            Text(summary.subtitle)
                .font(subtitleFont)
                .foregroundStyle(.secondary)
        }
        .accessibilitySortPriority(1)
    }

    private var collapseToggleButton: some View {
        Button(action: onToggleCollapse) {
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(toggleAccessibilityLabel)
    }

    private var insightsStateAccessibilityText: String {
        isCollapsed
            ? L10n.tr("patient.dashboard.insights.state.collapsed")
            : L10n.tr("patient.dashboard.insights.state.expanded")
    }

    private var toggleAccessibilityLabel: String {
        isCollapsed
            ? "\(summary.title), \(L10n.tr("patient.dashboard.insights.state.expanded"))"
            : "\(summary.title), \(L10n.tr("patient.dashboard.insights.state.collapsed"))"
    }
}
