import SwiftUI

/// Avatar circular reutilizable para pacientes.
/// Sin foto: muestra iniciales sobre fondo de color por género.
/// Con foto: muestra la foto circular.
/// Ambos casos llevan un anillo de color según el estado clínico:
/// verde (estable), naranja (en tratamiento), rojo (riesgo alto).
struct PatientAvatarView: View {

    let photoData: Data?
    let firstName: String
    let lastName: String
    let genderHint: String
    var clinicalStatus: String = "estable"
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // Fondo tenue circular con color por género
                Circle()
                    .fill(genderColor.opacity(0.12))

                // Iniciales del paciente (bold, color género)
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(genderColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // Anillo de estado clínico sobre el avatar
        .overlay(
            Circle()
                .strokeBorder(statusColor, lineWidth: max(size * 0.06, 2))
        )
    }

    // MARK: - Iniciales

    /// Primera letra del nombre + primera letra del apellido, en mayúsculas.
    /// Si falta alguno, muestra solo la inicial disponible.
    private var initials: String {
        let first = firstName.trimmingCharacters(in: .whitespaces).prefix(1)
        let last = lastName.trimmingCharacters(in: .whitespaces).prefix(1)
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }

    // MARK: - Color por género

    private var genderColor: Color {
        switch genderHint.lowercased() {
        case "masculino": .blue
        case "femenino": .pink
        default: .secondary
        }
    }

    // MARK: - Color del anillo por estado clínico

    private var statusColor: Color {
        switch clinicalStatus.lowercased() {
        case "estable": .green
        case "activo": .orange
        case "riesgo": .red
        default: .green
        }
    }
}

// MARK: - Preview

#Preview("Variantes de avatar") {
    VStack(spacing: 20) {
        // Tamaño lista (40pt) — sin foto, distintos estados
        HStack(spacing: 16) {
            PatientAvatarView(photoData: nil, firstName: "Ana", lastName: "García", genderHint: "femenino", clinicalStatus: "estable")
            PatientAvatarView(photoData: nil, firstName: "Carlos", lastName: "López", genderHint: "masculino", clinicalStatus: "activo")
            PatientAvatarView(photoData: nil, firstName: "Sam", lastName: "Pérez", genderHint: "", clinicalStatus: "riesgo")
        }

        // Tamaño detalle (64pt)
        HStack(spacing: 16) {
            PatientAvatarView(photoData: nil, firstName: "Ana", lastName: "García", genderHint: "femenino", clinicalStatus: "estable", size: 64)
            PatientAvatarView(photoData: nil, firstName: "Carlos", lastName: "López", genderHint: "masculino", clinicalStatus: "activo", size: 64)
            PatientAvatarView(photoData: nil, firstName: "Sam", lastName: "Pérez", genderHint: "", clinicalStatus: "riesgo", size: 64)
        }
    }
    .padding()
}
