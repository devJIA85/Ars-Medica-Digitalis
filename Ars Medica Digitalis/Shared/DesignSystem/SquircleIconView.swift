//
//  SquircleIconView.swift
//  Ars Medica Digitalis
//
//  Ícono SF Symbol dentro de un squircle (rect redondeado 12pt) de 40×40pt,
//  con fondo del mismo color al 15% de opacidad.
//  Usado en filas de navegación tipo "ACTIVIDAD" siguiendo el lenguaje Liquid Glass.
//

import SwiftUI

struct SquircleIconView: View {

    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.callout.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .background(
                color.opacity(0.15),
                in: RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
            )
    }
}

// MARK: - Preview

#Preview("SquircleIconView — variantes") {
    HStack(spacing: AppSpacing.lg) {
        SquircleIconView(systemImage: "chart.bar.xaxis", color: .blue)
        SquircleIconView(systemImage: "dollarsign.arrow.circlepath", color: .green)
        SquircleIconView(systemImage: "briefcase", color: .purple)
    }
    .padding(AppSpacing.xl)
}
