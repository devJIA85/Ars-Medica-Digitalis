//
//  StatisticsSection.swift
//  Ars Medica Digitalis
//
//  Accesos rapidos a tableros clinicos y financieros.
//

import SwiftUI

struct StatisticsSection: View {

    let professional: Professional
    let onShowFinances: () -> Void
    let onShowFees: () -> Void

    var body: some View {
        SettingsSectionCard(
            title: "Estadisticas",
            systemImage: "chart.pie",
            subtitle: "Accesos rapidos para revisar la actividad de la practica."
        ) {
            NavigationLink {
                DashboardView(professional: professional)
            } label: {
                SettingsRow(
                    systemImage: "chart.bar.xaxis",
                    title: "Dashboard",
                    subtitle: "Resumen clinico de la practica"
                ) {
                    rowChevron
                }
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: onShowFinances) {
                SettingsRow(
                    systemImage: "creditcard",
                    title: "Finanzas",
                    subtitle: "Ingresos, cobros y deuda por moneda"
                ) {
                    rowChevron
                }
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: onShowFees) {
                SettingsRow(
                    systemImage: "banknote",
                    title: "Honorarios",
                    subtitle: "Catalogo y valores vigentes"
                ) {
                    rowChevron
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var rowChevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
