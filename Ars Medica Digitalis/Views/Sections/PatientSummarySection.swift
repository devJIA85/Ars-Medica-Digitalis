//
//  PatientSummarySection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct PatientSummarySection: View {

    let patient: Patient
    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm, alignment: .leading),
        GridItem(.flexible(), spacing: AppSpacing.sm, alignment: .leading)
    ]

    var body: some View {
        SectionCard(
            title: "Datos del paciente",
            icon: "person.text.rectangle"
        ) {
            VStack(spacing: AppSpacing.sm) {
                LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                    ForEach(primaryItems, id: \.title) { item in
                        SummaryInfoCompactTile(
                            title: item.title,
                            value: item.value,
                            systemImage: item.systemImage,
                            fixedHeight: 44,
                            valueLineLimit: item.title == "Afiliado" ? 2 : 1
                        )
                    }
                }

                if let addressItem {
                    SummaryInfoCompactTile(
                        title: addressItem.title,
                        value: addressItem.value,
                        systemImage: addressItem.systemImage,
                        badge: addressItem.badge,
                        fixedHeight: 40,
                        valueLineLimit: 1
                    )
                }
            }
        }
    }

    private var primaryItems: [(title: String, value: String, systemImage: String)] {
        var items: [(title: String, value: String, systemImage: String)] = [
            ("Nacimiento", patient.dateOfBirth.compactDashboardDate, "birthday.cake"),
            ("DNI", displayValue(patient.nationalId), "person.text.rectangle"),
            ("Ocupación", displayValue(patient.occupation), "briefcase")
        ]

        if !patient.healthInsurance.trimmed.isEmpty {
            items.append(("Cobertura", patient.healthInsurance, "cross.case"))
        }

        if !patient.insuranceMemberNumber.trimmed.isEmpty {
            items.append(("Afiliado", patient.insuranceMemberNumber, "number"))
        }

        if !patient.insurancePlan.trimmed.isEmpty {
            items.append(("Plan", patient.insurancePlan, "checklist"))
        }

        return items
    }

    private var addressItem: (title: String, value: String, systemImage: String, badge: String?)? {
        let address = patient.address.trimmed
        let countryFlag = patient.residenceCountry.flagEmoji
        guard !address.isEmpty || countryFlag != nil else { return nil }
        return ("Dirección", address.isEmpty ? "Sin domicilio" : address, "house", countryFlag)
    }

    private func displayValue(_ rawValue: String) -> String {
        let trimmedValue = rawValue.trimmed
        return trimmedValue.isEmpty ? "No registrado" : trimmedValue
    }
}

private struct SummaryInfoCompactTile: View {

    let title: String
    let value: String
    let systemImage: String
    var badge: String? = nil
    var fixedHeight: CGFloat = 72
    var valueLineLimit: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12, height: 12)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)

                if let badge {
                    Text(badge)
                        .font(.caption)
                }
            }

            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(valueLineLimit)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .frame(maxWidth: .infinity, minHeight: fixedHeight, maxHeight: fixedHeight, alignment: .center)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

private extension Date {
    var compactDashboardDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: self)
    }
}
