//
//  StatisticsSection.swift
//  Ars Medica Digitalis
//
//  Sección ACTIVIDAD: accesos rápidos a tableros clínicos y financieros.
//  Rediseñada con íconos squircle y separadores con inset 56pt según spec Liquid Glass.
//  El título de sección se renderiza externamente en ProfileView para seguir
//  el patrón de cabecera externa en small-caps.
//

import SwiftUI

struct StatisticsSection: View {

    let professional: Professional
    let onShowFinances: () -> Void
    let onShowFees: () -> Void

    var body: some View {
        CardContainer(style: .flat) {
            VStack(spacing: 0) {

                // Dashboard Clínico → push con NavigationLink
                NavigationLink {
                    DashboardView(professional: professional)
                } label: {
                    activityRow(
                        systemImage: "chart.bar.xaxis",
                        color: .blue,
                        title: "Dashboard Clínico",
                        subtitle: "Insights, adherencia y prioridad de seguimiento"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.stats.clinicalDashboard")

                insetDivider

                // Finanzas → sheet
                Button(action: onShowFinances) {
                    activityRow(
                        systemImage: "dollarsign.arrow.circlepath",
                        color: .green,
                        title: "Finanzas",
                        subtitle: "Ingresos, cobros y deuda por moneda"
                    )
                }
                .buttonStyle(.plain)

                insetDivider

                // Honorarios → sheet
                Button(action: onShowFees) {
                    activityRow(
                        systemImage: "briefcase",
                        color: .purple,
                        title: "Honorarios",
                        subtitle: "Catálogo y valores vigentes"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    /// Fila de navegación con ícono squircle, títulos y chevron derecho.
    /// Área mínima de 44pt para accesibilidad.
    @ViewBuilder
    private func activityRow(
        systemImage: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            SquircleIconView(systemImage: systemImage, color: color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.sm)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        // Área de tap mínima 44pt para cumplir con accesibilidad
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    /// Divisor con inset 56pt para alinear con el texto (no con el ícono squircle).
    private var insetDivider: some View {
        Divider()
            .padding(.leading, 56)
    }
}
