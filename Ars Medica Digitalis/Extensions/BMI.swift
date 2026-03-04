//
//  BMI.swift
//  Ars Medica Digitalis
//
//  Utilidades compartidas para calculo y clasificacion de IMC.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

func calculateBMI(weightKg: Double, heightCm: Double) -> Double? {
    guard weightKg > 0, heightCm > 0 else { return nil }
    let heightM = heightCm / 100.0
    return weightKg / (heightM * heightM)
}

enum BMICategory: CaseIterable {
    case underweight
    case normal
    case overweight
    case obesity

    init?(bmi: Double) {
        guard bmi > 0 else { return nil }
        switch bmi {
        case ..<18.5:
            self = .underweight
        case 18.5..<25:
            self = .normal
        case 25..<30:
            self = .overweight
        default:
            self = .obesity
        }
    }

    var label: String {
        switch self {
        case .underweight: "Bajo peso"
        case .normal: "Normal"
        case .overweight: "Sobrepeso"
        case .obesity: "Obesidad"
        }
    }
}

#if canImport(SwiftUI)
extension BMICategory {
    var color: Color {
        switch self {
        case .underweight: Color(uiColor: .systemBrown)
        case .normal: Color(uiColor: .systemGreen)
        case .overweight: Color(uiColor: .systemOrange)
        case .obesity: Color(uiColor: .systemRed)
        }
    }
}
#endif
