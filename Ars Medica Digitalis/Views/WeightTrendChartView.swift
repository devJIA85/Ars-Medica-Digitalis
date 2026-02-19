//
//  WeightTrendChartView.swift
//  Ars Medica Digitalis
//
//  Gráfico de tendencia temporal de peso e IMC usando Swift Charts.
//  Requiere al menos 2 registros antropométricos para mostrarse,
//  ya que un solo punto no define una tendencia clínicamente útil.
//

import SwiftUI
import Charts

struct WeightTrendChartView: View {

    let records: [AnthropometricRecord]

    /// Selector para alternar entre peso e IMC
    @State private var selectedMetric: Metric = .weight

    enum Metric: String, CaseIterable {
        case weight = "Peso"
        case bmi = "IMC"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selector de métrica
            Picker("Métrica", selection: $selectedMetric) {
                ForEach(Metric.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            // Gráfico de línea con puntos individuales
            Chart(sortedRecords) { record in
                LineMark(
                    x: .value("Fecha", record.recordDate),
                    y: .value(selectedMetric.rawValue, yValue(for: record))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.tint)

                PointMark(
                    x: .value("Fecha", record.recordDate),
                    y: .value(selectedMetric.rawValue, yValue(for: record))
                )
                .foregroundStyle(.tint)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)

            // Resumen: variación total desde el primer registro
            if let first = sortedRecords.first, let last = sortedRecords.last,
               sortedRecords.count >= 2 {
                let delta = yValue(for: last) - yValue(for: first)
                let sign = delta >= 0 ? "+" : ""
                Text("\(sign)\(String(format: "%.1f", delta)) \(unitLabel) desde \(first.recordDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    /// Registros filtrados (solo con datos válidos) y ordenados cronológicamente
    private var sortedRecords: [AnthropometricRecord] {
        records
            .filter { selectedMetric == .weight ? $0.weightKg > 0 : ($0.bmi != nil) }
            .sorted { $0.recordDate < $1.recordDate }
    }

    private func yValue(for record: AnthropometricRecord) -> Double {
        switch selectedMetric {
        case .weight: record.weightKg
        case .bmi: record.bmi ?? 0
        }
    }

    private var unitLabel: String {
        switch selectedMetric {
        case .weight: "kg"
        case .bmi: "pts IMC"
        }
    }
}

// MARK: - Preview

#Preview("Tendencia de peso") {
    // Datos sample simulando evolución de 6 meses
    let calendar = Calendar.current
    let now = Date()
    let sampleRecords: [AnthropometricRecord] = [
        AnthropometricRecord(
            recordDate: calendar.date(byAdding: .month, value: -5, to: now)!,
            weightKg: 85.0, heightCm: 175, waistCm: 92
        ),
        AnthropometricRecord(
            recordDate: calendar.date(byAdding: .month, value: -4, to: now)!,
            weightKg: 83.5, heightCm: 175, waistCm: 90
        ),
        AnthropometricRecord(
            recordDate: calendar.date(byAdding: .month, value: -3, to: now)!,
            weightKg: 82.0, heightCm: 175, waistCm: 88
        ),
        AnthropometricRecord(
            recordDate: calendar.date(byAdding: .month, value: -2, to: now)!,
            weightKg: 80.5, heightCm: 175, waistCm: 87
        ),
        AnthropometricRecord(
            recordDate: calendar.date(byAdding: .month, value: -1, to: now)!,
            weightKg: 79.0, heightCm: 175, waistCm: 85
        ),
        AnthropometricRecord(
            recordDate: now,
            weightKg: 78.0, heightCm: 175, waistCm: 84
        ),
    ]

    WeightTrendChartView(records: sampleRecords)
        .padding()
}
