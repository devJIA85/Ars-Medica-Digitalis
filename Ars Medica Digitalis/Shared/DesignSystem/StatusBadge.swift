//
//  StatusBadge.swift
//  Ars Medica Digitalis
//
//  Badge semántico reutilizable con Capsule + thinMaterial.
//  Unifica statusBadge (PatientListView) y SessionTypeBadge (PatientDetailView),
//  que eran implementaciones distintas del mismo concepto visual.
//

import SwiftUI

struct StatusBadge: View {

    enum Variant {
        case success   // estado positivo (activo, completado)
        case warning   // atención (pendiente, programado)
        case danger    // alerta (riesgo, cancelado)
        case neutral   // estado inactivo o sin relevancia clínica
        case custom(Color)

        // Color semántico — sin hex hardcodeados; se adapta a light/dark mode
        var color: Color {
            switch self {
            case .success:       .green
            case .warning:       .orange
            case .danger:        .red
            case .neutral:       .secondary
            case .custom(let c): c
            }
        }
    }

    let label: String
    var variant: Variant = .neutral
    /// Cuando se provee un systemImage se muestra el ícono SF Symbols;
    /// cuando es nil se muestra un indicador circular (como en statusBadge original).
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
            } else {
                Circle()
                    .fill(variant.color)
                    .frame(width: 7, height: 7)
            }
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(variant.color)
        .padding(.horizontal, AppSpacing.sm + 1)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule(style: .continuous))
    }
}

// MARK: - Preview

#Preview("StatusBadge — variantes") {
    VStack(spacing: AppSpacing.md) {
        HStack(spacing: AppSpacing.sm) {
            StatusBadge(label: "Activo",     variant: .success)
            StatusBadge(label: "Programada", variant: .warning)
            StatusBadge(label: "Cancelada",  variant: .danger)
            StatusBadge(label: "Inactivo",   variant: .neutral)
        }
        HStack(spacing: AppSpacing.sm) {
            StatusBadge(label: "Completada",  variant: .success,            systemImage: "checkmark.circle")
            StatusBadge(label: "Programada",  variant: .warning,            systemImage: "clock")
            StatusBadge(label: "Presencial",  variant: .custom(.blue),      systemImage: "person.2.wave.2")
            StatusBadge(label: "Video",       variant: .custom(.indigo),    systemImage: "video")
        }
    }
    .padding()
}
