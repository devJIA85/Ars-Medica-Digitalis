//
//  ICD11ChipView.swift
//  Ars Medica Digitalis
//
//  Píldora de código o categoría CIE-11.
//  Compartida entre ICD11SearchView y las vistas de diagnósticos asignados
//  para que la misma entidad tenga el mismo aspecto visual en cualquier contexto.
//
//  Emphasis.high  → código MMS (ej: 6A70) — identificador primario, peso mayor.
//  Emphasis.low   → capítulo (ej: Salud mental) — contexto secundario, peso reducido.
//

import SwiftUI

// MARK: - View

struct ICD11ChipView: View {

    enum Emphasis {
        /// Identificador principal — mayor opacidad, semibold.
        case high
        /// Metadato contextual — menor opacidad, regular.
        case low
    }

    let text: String
    let color: Color
    var emphasis: Emphasis = .high

    private var textOpacity: Double   { emphasis == .high ? 1.0  : 0.65 }
    private var bgOpacity: Double     { emphasis == .high ? 0.18 : 0.10 }
    private var fontWeight: Font.Weight { emphasis == .high ? .semibold : .regular }

    var body: some View {
        Text(text)
            .font(.caption.weight(fontWeight))
            .foregroundStyle(color.opacity(textOpacity))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(bgOpacity), in: Capsule())
    }
}

// MARK: - Chapter color

/// Devuelve un color determinista según el código de capítulo CIE-11.
/// El mismo capítulo produce siempre el mismo color en cualquier vista.
func icd11ChapterColor(for chapter: String?) -> Color {
    guard let chapter, !chapter.isEmpty else { return .blue }
    let palette: [Color] = [.blue, .teal, .green, .mint, .indigo, .cyan, .orange, .pink]
    let hash = chapter.unicodeScalars.reduce(into: 0) { $0 += Int($1.value) }
    return palette[hash % palette.count]
}

// MARK: - Chapter name

/// Nombre clínico corto del capítulo CIE-11 en español.
/// Cubre todos los capítulos de la linearización MMS 2024-01.
/// Fallback: "Cap. XX" si el código no está en la tabla.
func icd11ChapterName(for code: String?) -> String {
    guard let code, !code.isEmpty else { return "" }
    return icd11ChapterNames[code] ?? "Cap. \(code)"
}

private let icd11ChapterNames: [String: String] = [
    "01": "Infecciosas",
    "02": "Neoplasias",
    "03": "Sangre",
    "04": "Inmunología",
    "05": "Endocrino",
    "06": "Salud mental",
    "07": "Sueño",
    "08": "Neurología",
    "09": "Oftalmología",
    "10": "Otología",
    "11": "Cardiología",
    "12": "Respiratorio",
    "13": "Digestivo",
    "14": "Dermatología",
    "15": "Musculoesquelético",
    "16": "Urología",
    "17": "Salud sexual",
    "18": "Obstetricia",
    "19": "Perinatal",
    "20": "Congénito",
    "21": "Síntomas",
    "22": "Traumatología",
    "23": "Causas externas",
    "24": "Factores de salud",
    "25": "Especiales",
    "26": "Sustancias",
]
