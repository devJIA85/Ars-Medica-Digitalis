//
//  BMIGaugeView.swift
//  Ars Medica Digitalis
//
//  Gauge visual del IMC usando Swift Charts.
//  Muestra el valor del paciente posicionado dentro
//  de los rangos de clasificación de la OMS:
//  bajo peso (<18.5), normal (18.5–25), sobrepeso (25–30), obesidad (≥30).
//

import SwiftUI
import Charts

struct BMIGaugeView: View {

    let bmiValue: Double

    var body: some View {
        VStack(spacing: 8) {
            // Valor prominente con categoría
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", bmiValue))
                    .font(.title2.bold())
                    .foregroundStyle(bmiColor)

                Text(bmiCategory)
                    .font(.caption)
                    .foregroundStyle(bmiColor)
            }

            // Barra horizontal segmentada con indicador del valor actual.
            // Cada segmento corresponde a un rango OMS con color semántico.
            Chart {
                // Bajo peso: 10–18.5
                BarMark(
                    xStart: .value("Inicio", 10),
                    xEnd: .value("Fin", 18.5),
                    y: .value("IMC", "IMC")
                )
                .foregroundStyle(.orange.opacity(0.3))

                // Normal: 18.5–25
                BarMark(
                    xStart: .value("Inicio", 18.5),
                    xEnd: .value("Fin", 25),
                    y: .value("IMC", "IMC")
                )
                .foregroundStyle(.green.opacity(0.3))

                // Sobrepeso: 25–30
                BarMark(
                    xStart: .value("Inicio", 25),
                    xEnd: .value("Fin", 30),
                    y: .value("IMC", "IMC")
                )
                .foregroundStyle(.orange.opacity(0.3))

                // Obesidad: 30–45
                BarMark(
                    xStart: .value("Inicio", 30),
                    xEnd: .value("Fin", 45),
                    y: .value("IMC", "IMC")
                )
                .foregroundStyle(.red.opacity(0.3))

                // Indicador del valor actual del paciente
                RuleMark(x: .value("IMC Actual", clampedBMI))
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .foregroundStyle(bmiColor)
                    .annotation(position: .top) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.caption2)
                            .foregroundStyle(bmiColor)
                    }
            }
            .chartXScale(domain: 10...45)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: [18.5, 25, 30]) { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .frame(height: 40)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    /// Clampea el IMC al rango visible del gráfico
    /// para que el indicador no se salga del área de dibujo
    private var clampedBMI: Double {
        min(max(bmiValue, 10), 45)
    }

    /// Color según clasificación OMS
    private var bmiColor: Color {
        switch bmiValue {
        case ..<18.5: .orange
        case 18.5..<25: .green
        case 25..<30: .orange
        default: .red
        }
    }

    /// Categoría textual según clasificación OMS
    private var bmiCategory: String {
        switch bmiValue {
        case ..<18.5: "Bajo peso"
        case 18.5..<25: "Normal"
        case 25..<30: "Sobrepeso"
        default: "Obesidad"
        }
    }
}

// MARK: - Preview

#Preview("Rangos IMC") {
    VStack(spacing: 24) {
        BMIGaugeView(bmiValue: 17.0)
        BMIGaugeView(bmiValue: 22.5)
        BMIGaugeView(bmiValue: 27.3)
        BMIGaugeView(bmiValue: 35.0)
    }
    .padding()
}
