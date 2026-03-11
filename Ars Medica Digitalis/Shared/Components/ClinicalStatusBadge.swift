//
//  ClinicalStatusBadge.swift
//  Ars Medica Digitalis
//
//  Indicador compacto del estado clínico del paciente.
//  Muestra un SF Symbol + etiqueta semántica con color contextual
//  para comunicar estabilidad, actividad o riesgo de un vistazo.
//

import SwiftUI

struct ClinicalStatusBadge: View {

    let status: ClinicalStatusMapping

    private var isRisk: Bool { status == .riesgo }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.caption2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)

            Text(status.label)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(status.tint)
        .phaseAnimator([false, true]) { content, pulse in
            content.opacity(isRisk && pulse ? 0.7 : 1.0)
        } animation: { _ in
            isRisk ? .easeInOut(duration: 1.5) : .default
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estado clínico: \(status.label)")
    }

    private var symbolName: String {
        switch status {
        case .estable:
            "checkmark.circle.fill"
        case .activo:
            "exclamationmark.triangle.fill"
        case .riesgo:
            "exclamationmark.octagon.fill"
        }
    }
}

#Preview("ClinicalStatusBadge") {
    VStack(spacing: AppSpacing.md) {
        ClinicalStatusBadge(status: .estable)
        ClinicalStatusBadge(status: .activo)
        ClinicalStatusBadge(status: .riesgo)
    }
    .padding()
}
