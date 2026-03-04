//
//  RiskFactorsSection.swift
//  Ars Medica Digitalis
//

import SwiftUI

struct RiskFactorsSection: View {

    let patient: Patient

    var body: some View {
        CardContainer(
            title: "Factores de riesgo",
            systemImage: "exclamationmark.shield",
            style: .flat
        ) {
            VStack(spacing: 0) {
                ForEach(Array(riskFactors.enumerated()), id: \.element.title) { index, factor in
                    HStack(spacing: AppSpacing.sm) {
                        Label(factor.title, systemImage: factor.systemImage)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)

                        StatusBadge(
                            label: factor.isActive ? "Sí" : "No",
                            variant: factor.isActive ? .warning : .neutral
                        )
                    }
                    .padding(.vertical, AppSpacing.xs)

                    if index < riskFactors.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var riskFactors: [(title: String, systemImage: String, isActive: Bool)] {
        [
            ("Tabaquismo", "smoke", patient.smokingStatus),
            ("Consumo de alcohol", "wineglass", patient.alcoholUse),
            ("Consumo de drogas", "pill", patient.drugUse),
            ("Chequeos de rutina", "heart.text.clipboard", patient.routineCheckups)
        ]
    }
}
