//
//  ClinicalInsightsCard.swift
//  Ars Medica Digitalis
//
//  Card principal de inteligencia clínica con diseño iOS 26 / Liquid Glass.
//
//  QUÉ HACE:
//  Contenedor principal que orquesta las 3 capas del panel de insights clínicos:
//    Capa 1 — ClinicalRiskRing: anillo de riesgo global (domina visualmente)
//    Capa 2 — ClinicalTrendView: indicadores de tendencia como pills glass
//    Capa 3 — ClinicalMetricsGrid: grid 2x2 de métricas operacionales
//  Soporta dos modos: expandido (3 capas completas) y colapsado (resumen compacto).
//
//  POR QUÉ:
//  - El fondo usa .thinMaterial en lugar de .glassEffect() directo para todo
//    el card, siguiendo la guía de Apple: "Avoid overusing Liquid Glass effects.
//    Limit these effects to the most important functional elements."
//    Los elementos que sí usan glass son las pills de trends y el botón de colapso.
//  - La transición collapsed↔expanded usa spring animation con
//    .animation(.spring, value: isCollapsed) para que el cambio se sienta fluido
//    y nativo, como las transiciones de iOS 26 en Health/Fitness.
//  - El modo colapsado mantiene el mini radar + conteo numérico + trend principal
//    para preservar contexto clínico mínimo sin sacrificar espacio vertical.
//  - Se eliminan los bordes coloreados (strokeBorder) del diseño anterior
//    y se usa una sombra muy sutil (.shadow con opacidad 0.04) para depth
//    sin ruido visual, alineado con la estética de profundidad de iOS 26.
//  - El separador entre trends y métricas usa Divider nativo con opacidad
//    reducida para crear separación visual sin peso cromático.
//  - El botón de colapso usa .buttonStyle(.glass) como un elemento Liquid Glass
//    puntual e interactivo, siguiendo la guía: "Add interactive() to custom
//    components to make them react to touch and pointer interactions."
//

import SwiftUI

// MARK: - ClinicalInsightsCard

/// Card principal de insights clínicos con jerarquía de 3 capas y modo colapsado.
/// Reemplaza ClinicalInsightsHeader con diseño iOS 26 nativo.
struct ClinicalInsightsCard: View {

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

    /// Init de conveniencia para uso simplificado (ej. ClinicalDashboardView)
    /// que construye el summary a partir de valores individuales.
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
                    animationDelay: 0.04
                ),
                InsightMetric(
                    id: "adherence",
                    value: "\(adherencePercentage)%",
                    title: L10n.tr("patient.dashboard.metric.adherence.title"),
                    description: L10n.tr("patient.dashboard.metric.adherence.subtitle"),
                    systemImage: "checkmark.seal.fill",
                    tone: .positive,
                    accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.adherence.title")): \(adherencePercentage)%",
                    animationDelay: 0.08
                ),
                InsightMetric(
                    id: "sessionGap",
                    value: "\(patientsWithoutSession30Days)",
                    title: L10n.tr("patient.dashboard.metric.session_gap.title"),
                    description: L10n.tr("patient.dashboard.metric.session_gap.subtitle"),
                    systemImage: "calendar.badge.exclamationmark",
                    tone: .informational,
                    accessibilityLabel: "\(L10n.tr("patient.dashboard.metric.session_gap.title")): \(patientsWithoutSession30Days)",
                    animationDelay: 0.12
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
        .padding(.vertical, isCollapsed ? 12 : 19)
        .frame(minHeight: isCollapsed ? 64 : nil)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isCollapsed)
        .glassCardEntrance()
    }

    // MARK: - Layout expandido

    private var expandedLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            ClinicalRiskRing(
                model: summary.radarModel,
                selectedBucket: selectedRadarBucket,
                onSelectBucket: onSelectRadarBucket
            )
            .transition(.opacity.combined(with: .scale(scale: 1.02, anchor: .top)))

            ClinicalTrendView(trends: summary.trends)
                .transition(.opacity.combined(with: .move(edge: .top)))

            ClinicalMetricsGrid(metrics: summary.metrics)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Layout colapsado

    private var collapsedLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                titleBlock(titleFont: .headline.weight(.semibold), subtitleFont: .caption)
                Spacer(minLength: 0)
                collapseToggleButton
            }

            ClinicalRiskRing(
                model: summary.radarModel,
                selectedBucket: selectedRadarBucket,
                onSelectBucket: onSelectRadarBucket,
                ringSize: .mini
            )
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Componentes compartidos

    private var headerRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            titleBlock(titleFont: .title3.weight(.semibold), subtitleFont: .footnote)
            Spacer(minLength: 0)
            collapseToggleButton
        }
    }

    private func titleBlock(titleFont: Font, subtitleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.title)
                .font(titleFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .accessibilityLabel("\(summary.title), \(insightsStateLabel)")

            Text(summary.subtitle)
                .font(subtitleFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilitySortPriority(1)
    }

    private var collapseToggleButton: some View {
        Button(action: onToggleCollapse) {
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(toggleAccessibilityLabel)
    }

    // MARK: - Accesibilidad

    private var insightsStateLabel: String {
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

// MARK: - Preview con datos mock

#Preview("ClinicalInsightsCard — Expandido") {
    let radarModel = ClinicalPriorityRadarModel(
        totalCount: 24,
        criticalCount: 5,
        attentionCount: 8,
        stableCount: 11
    )

    ScrollView {
        ClinicalInsightsCard(
            summary: ClinicalInsightsSummary(
                totalPatients: 24,
                title: "Inteligencia Clínica",
                subtitle: "24 pacientes analizados",
                criticalPatientsCount: 5,
                attentionPatientsCount: 8,
                stablePatientsCount: 11,
                trends: [
                    ClinicalTrend(
                        id: "adherence",
                        systemImage: "checkmark.seal.fill",
                        displayLabel: "↑ Adherencia",
                        tone: .positive,
                        accessibilityLabel: "Adherencia, en aumento"
                    ),
                    ClinicalTrend(
                        id: "dropout",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        displayLabel: "↓ Riesgo de abandono",
                        tone: .caution,
                        accessibilityLabel: "Riesgo de abandono, disminuyendo"
                    ),
                    ClinicalTrend(
                        id: "continuity",
                        systemImage: "waveform.path.ecg",
                        displayLabel: "→ Continuidad",
                        tone: .neutral,
                        accessibilityLabel: "Continuidad, estable"
                    ),
                    ClinicalTrend(
                        id: "stability",
                        systemImage: "shield.checkered",
                        displayLabel: "↑ Estabilidad",
                        tone: .positive,
                        accessibilityLabel: "Estabilidad, en aumento"
                    ),
                ],
                metrics: [
                    InsightMetric(
                        id: "critical",
                        value: "5",
                        title: "Pacientes Críticos",
                        description: "Seguimiento inmediato",
                        systemImage: "cross.case.fill",
                        tone: .critical,
                        accessibilityLabel: "Pacientes Críticos: 5",
                        animationDelay: 0
                    ),
                    InsightMetric(
                        id: "dropout",
                        value: "8",
                        title: "Riesgo de Abandono",
                        description: "Alto riesgo de dropout",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        tone: .warning,
                        accessibilityLabel: "Riesgo de Abandono: 8",
                        animationDelay: 0.04
                    ),
                    InsightMetric(
                        id: "adherence",
                        value: "72%",
                        title: "Adherencia",
                        description: "Promedio general",
                        systemImage: "checkmark.seal.fill",
                        tone: .positive,
                        accessibilityLabel: "Adherencia: 72%",
                        animationDelay: 0.08
                    ),
                    InsightMetric(
                        id: "sessionGap",
                        value: "3",
                        title: "30d Sin Sesión",
                        description: "Pacientes inactivos",
                        systemImage: "calendar.badge.exclamationmark",
                        tone: .informational,
                        accessibilityLabel: "30d Sin Sesión: 3",
                        animationDelay: 0.12
                    ),
                ],
                radarModel: radarModel
            ),
            isCollapsed: false,
            onToggleCollapse: {}
        )
        .padding(.horizontal)
    }
}

#Preview("ClinicalInsightsCard — Colapsado") {
    let radarModel = ClinicalPriorityRadarModel(
        totalCount: 24,
        criticalCount: 5,
        attentionCount: 8,
        stableCount: 11
    )

    ClinicalInsightsCard(
        summary: ClinicalInsightsSummary(
            totalPatients: 24,
            title: "Inteligencia Clínica",
            subtitle: "24 pacientes analizados",
            criticalPatientsCount: 5,
            attentionPatientsCount: 8,
            stablePatientsCount: 11,
            trends: [
                ClinicalTrend(
                    id: "adherence",
                    systemImage: "checkmark.seal.fill",
                    displayLabel: "↑ Adherencia",
                    tone: .positive,
                    accessibilityLabel: "Adherencia, en aumento"
                ),
            ],
            metrics: [],
            radarModel: radarModel
        ),
        isCollapsed: true,
        onToggleCollapse: {}
    )
    .padding(.horizontal)
}
