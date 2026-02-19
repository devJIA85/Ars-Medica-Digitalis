import SwiftUI

/// Avatar circular reutilizable para pacientes.
/// Muestra la foto del paciente si existe, o un SF Symbol según género
/// con color indicativo para reconocimiento visual rápido:
/// azul (masculino), rosa (femenino), gris (otro/sin especificar).
struct PatientAvatarView: View {

    let photoData: Data?
    let genderHint: String
    var size: CGFloat = 40

    var body: some View {
        // Frame fijo para que foto y fallback tengan el mismo tamaño visual.
        // Se usa ZStack en vez de Group para que el fondo del fallback
        // no afecte el layout de la foto.
        ZStack {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // Fondo tenue circular
                Circle()
                    .fill(avatarColor.opacity(0.12))

                // SF Symbol con tamaño fijo basado en font.
                // Usar .font() en vez de .resizable() garantiza que
                // todos los símbolos (figure.stand, figure.stand.dress,
                // person.crop.circle.fill) se rendericen al mismo tamaño
                // óptico sin importar su aspect ratio intrínseco.
                Image(systemName: avatarSymbol)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(avatarColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    // MARK: - Lógica de símbolo

    /// SF Symbol diferenciado para identificar género a simple vista
    private var avatarSymbol: String {
        switch genderHint.lowercased() {
        case "masculino": "figure.stand"
        case "femenino": "figure.stand.dress"
        default: "person.crop.circle.fill"
        }
    }

    /// Color diferenciado para accesibilidad visual rápida en listas
    private var avatarColor: Color {
        switch genderHint.lowercased() {
        case "masculino": .blue
        case "femenino": .pink
        default: .secondary
        }
    }
}

// MARK: - Preview

#Preview("Variantes de avatar") {
    VStack(spacing: 20) {
        // Tamaño lista (40pt)
        HStack(spacing: 16) {
            PatientAvatarView(photoData: nil, genderHint: "masculino", size: 40)
            PatientAvatarView(photoData: nil, genderHint: "femenino", size: 40)
            PatientAvatarView(photoData: nil, genderHint: "", size: 40)
        }

        // Tamaño detalle (64pt)
        HStack(spacing: 16) {
            PatientAvatarView(photoData: nil, genderHint: "masculino", size: 64)
            PatientAvatarView(photoData: nil, genderHint: "femenino", size: 64)
            PatientAvatarView(photoData: nil, genderHint: "", size: 64)
        }
    }
    .padding()
}
