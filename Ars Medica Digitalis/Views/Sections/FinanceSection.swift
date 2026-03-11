//
//  FinanceSection.swift
//  Ars Medica Digitalis
//
//  Configuracion financiera reutilizable para defaults administrativos.
//  El título de sección se renderiza externamente en ProfileView (small-caps "PREFERENCIAS").
//

import SwiftUI

struct FinanceSection: View {

    @Binding var defaultPatientCurrencyCode: String
    @Binding var defaultFinancialSessionTypeID: UUID?

    let sessionTypes: [SessionCatalogType]
    let onManageFees: () -> Void

    var body: some View {
        CardContainer(style: .flat) {
            VStack(spacing: 0) {
                SettingsRow(
                    systemImage: "dollarsign.circle",
                    title: "Moneda base",
                    subtitle: "Se asigna a pacientes nuevos"
                ) {
                    currencyMenu
                }

                Divider()

                SettingsRow(
                    systemImage: "creditcard.and.123",
                    title: "Honorario sugerido",
                    subtitle: "Tipo facturable preferido para sesiones nuevas"
                ) {
                    sessionTypeMenu
                }

                Divider()

                Button(action: onManageFees) {
                    SettingsRow(
                        systemImage: "slider.horizontal.3",
                        title: "Gestionar honorarios",
                        subtitle: sessionTypes.isEmpty
                        ? "Crea tu primer honorario para habilitar sugerencias"
                        : "\(sessionTypes.count) tipos activos disponibles"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var currencyMenu: some View {
        Menu {
            Button("Sin configurar") {
                defaultPatientCurrencyCode = ""
            }

            ForEach(CurrencyCatalog.common) { currency in
                Button(currency.displayLabel) {
                    defaultPatientCurrencyCode = currency.code
                }
            }
        } label: {
            SettingsMenuLabel(title: selectedCurrencyLabel)
        }
        .accessibilityLabel("Seleccionar moneda base")
    }

    private var sessionTypeMenu: some View {
        Menu {
            Button("Sin configurar") {
                defaultFinancialSessionTypeID = nil
            }

            ForEach(sessionTypes, id: \.id) { sessionType in
                Button(sessionType.name) {
                    defaultFinancialSessionTypeID = sessionType.id
                }
            }
        } label: {
            SettingsMenuLabel(title: selectedSessionTypeLabel)
        }
        .disabled(sessionTypes.isEmpty)
        .accessibilityLabel("Seleccionar honorario sugerido")
    }

    private var selectedCurrencyLabel: String {
        defaultPatientCurrencyCode.isEmpty
        ? "Sin configurar"
        : defaultPatientCurrencyCode
    }

    private var selectedSessionTypeLabel: String {
        guard let defaultFinancialSessionTypeID,
              let sessionType = sessionTypes.first(where: { $0.id == defaultFinancialSessionTypeID }) else {
            return sessionTypes.isEmpty ? "Sin honorarios" : "Sin configurar"
        }

        return sessionType.name
    }
}

private struct SettingsMenuLabel: View {

    let title: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }
}
