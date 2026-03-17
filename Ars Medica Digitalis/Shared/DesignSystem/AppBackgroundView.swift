//
//  AppBackgroundView.swift
//  Ars Medica Digitalis
//
//  Fondo visual global con gradiente difuminado parametrizado por color base.
//

import SwiftUI

/// Renderiza un fondo suave estilo Apple Health que ocupa toda la pantalla.
/// Se coloca como capa inferior en un ZStack y adapta sus tonos al color base recibido.
/// Usa proporciones relativas (GeometryReader) para escalar correctamente
/// en distintos tamaños de pantalla (iPhone SE → iPad).
struct AppBackgroundView: View {

    let baseColor: Color

    var body: some View {
        GeometryReader { geo in
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

                // Mancha difusa superior-izquierda
                Circle()
                    .fill(baseColor.opacity(0.14))
                    .frame(
                        width: geo.size.width * 0.70,
                        height: geo.size.width * 0.70
                    )
                    .blur(radius: 28)
                    .offset(
                        x: -geo.size.width * 0.30,
                        y: -geo.size.height * 0.30
                    )

                // Mancha difusa inferior-derecha
                Circle()
                    .fill(baseColor.opacity(0.10))
                    .frame(
                        width: geo.size.width * 0.80,
                        height: geo.size.width * 0.80
                    )
                    .blur(radius: 36)
                    .offset(
                        x: geo.size.width * 0.45,
                        y: geo.size.height * 0.28
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Modifier conveniente

/// Aplica AppBackgroundView como fondo leyendo el color de tema de AppStorage.
/// Uso: `.themedBackground()` en cualquier vista principal.
private struct ThemedBackgroundModifier: ViewModifier {

    @AppStorage("appearance.themeColor") private var themeColorRaw: String = AppThemeColor.blue.rawValue

    func body(content: Content) -> some View {
        content
            .background {
                AppBackgroundView(
                    baseColor: (AppThemeColor(rawValue: themeColorRaw) ?? .blue).color
                )
            }
            .animation(.easeInOut(duration: 0.35), value: themeColorRaw)
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }
}
