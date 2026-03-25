//
//  RiskFactorsSection.swift
//  Ars Medica Digitalis
//
//  Two-column compact grid — no chevrons, no delete affordance.
//  Delete was dead code (swipe actions require List context, not VStack).
//

import SwiftUI

struct RiskFactorsSection: View {

    let patient: Patient
    let onEditMedicalHistory: () -> Void

    var body: some View {
        SectionCard(
            title: "Factores de riesgo",
            icon: "exclamationmark.shield",
            prominence: .secondary
        ) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppSpacing.sm
            ) {
                ForEach(riskFactors, id: \.title) { factor in
                    Button(action: onEditMedicalHistory) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(factor.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(factor.isActive ? "Sí" : "No")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(factor.valueColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.sm)
                        .background(
                            .quaternary.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var riskFactors: [(title: String, isActive: Bool, valueColor: Color)] {
        [
            ("Tabaquismo",        patient.smokingStatus,   patient.smokingStatus   ? Color.red    : Color.secondary),
            ("Alcohol",           patient.alcoholUse,      patient.alcoholUse      ? Color.orange : Color.secondary),
            ("Drogas",            patient.drugUse,         patient.drugUse         ? Color.red    : Color.secondary),
            ("Chequeos de rutina", patient.routineCheckups, patient.routineCheckups ? Color.green  : Color.secondary)
        ]
    }
}
