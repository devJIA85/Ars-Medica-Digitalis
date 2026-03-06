//
//  AppBackgroundView.swift
//  Ars Medica Digitalis
//
//  Fondo visual global con gradiente difuminado parametrizado por color base.
//

import SwiftUI

/// Renderiza un fondo suave estilo Apple Health que ocupa toda la pantalla.
/// Se coloca como capa inferior en un ZStack y adapta sus tonos al color base recibido.
struct AppBackgroundView: View {

    let baseColor: Color

    var body: some View {
        ZStack {
            // Gradiente base sutil: fondo del sistema hacia el color de tema.
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    baseColor.opacity(0.10),
                    baseColor.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Manchas difusas para profundidad visual.
            Circle()
                .fill(baseColor.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 28)
                .offset(x: -120, y: -250)

            Circle()
                .fill(baseColor.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 36)
                .offset(x: 180, y: 220)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
