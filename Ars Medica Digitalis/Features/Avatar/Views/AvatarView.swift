//
//  AvatarView.swift
//  Ars Medica Digitalis
//
//  Componente circular reutilizable que renderiza cualquier AvatarConfiguration.
//  Soporta tamaños small/medium/large y anima la transición entre configuraciones.
//

import SwiftUI

// MARK: - Tamaños

enum AvatarSize {
    case small       // 40 pt — rows de lista
    case medium      // 64 pt — cabecera de perfil
    case large       // 96 pt — selector / wizard

    var diameter: CGFloat {
        switch self {
        case .small:  return 40
        case .medium: return 64
        case .large:  return 96
        }
    }

    var symbolFontSize: CGFloat {
        switch self {
        case .small:  return 24
        case .medium: return 38
        case .large:  return 56
        }
    }
}

// MARK: - AvatarView

/// Vista circular que renderiza un `AvatarConfiguration`.
///
/// La transición entre configuraciones se anima con spring (cambia junto con
/// `configuration` para evitar flashes al actualizar el pendiente en el selector).
///
/// Uso:
/// ```swift
/// AvatarView(configuration: .predefined(style: .teal), size: .medium)
/// AvatarView(configuration: vm.preview, size: .large, generatedImage: vm.generatedImage)
/// ```
struct AvatarView: View {

    let configuration: AvatarConfiguration
    var size: AvatarSize = .medium
    /// Imagen generada precargada. nil si la configuración es predefined.
    var generatedImage: Image? = nil

    var body: some View {
        ZStack {
            // Fondo: círculo translúcido con trazo reflectante (estilo Liquid Glass)
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )

            Group {
                switch configuration {
                case .predefined(let style):
                    predefinedLayer(style: style)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))

                case .generated:
                    generatedLayer
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            // id fuerza re-renderizado de la capa cuando cambia la configuración,
            // habilitando la transición de salida del estado anterior.
            .id(configuration)
        }
        .frame(width: size.diameter, height: size.diameter)
        .clipShape(Circle())
        // Anima cambios de configuración con un spring suave
        .animation(.spring(duration: 0.35, bounce: 0.2), value: configuration)
    }

    // MARK: - Capas

    private func predefinedLayer(style: PredefinedAvatarStyle) -> some View {
        Image(systemName: style.sfSymbol)
            .font(.system(size: size.symbolFontSize))
            .foregroundStyle(style.color)
            .symbolRenderingMode(.hierarchical)
    }

    @ViewBuilder
    private var generatedLayer: some View {
        if let image = generatedImage {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size.diameter, height: size.diameter)
                .clipShape(Circle())
        } else {
            // Placeholder mientras carga o si el archivo no se encontró
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: size.symbolFontSize))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            ForEach([AvatarSize.small, .medium, .large], id: \.diameter) { size in
                AvatarView(configuration: .predefined(style: .teal), size: size)
            }
        }
        HStack(spacing: 12) {
            ForEach(PredefinedAvatarStyle.allCases) { style in
                AvatarView(configuration: .predefined(style: style), size: .small)
            }
        }
    }
    .padding()
}
