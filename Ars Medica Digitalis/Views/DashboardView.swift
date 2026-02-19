//
//  DashboardView.swift
//  Ars Medica Digitalis
//
//  Dashboard de estadísticas del profesional.
//  Muestra KPIs, distribuciones demográficas, diagnósticos frecuentes,
//  actividad de sesiones, factores de riesgo y crecimiento de la práctica.
//  Accesible desde ProfileEditView via NavigationLink.
//

import SwiftUI
import Charts
import SwiftData

struct DashboardView: View {

    let professional: Professional
    @Query private var patients: [Patient]

    @State private var viewModel = DashboardViewModel()

    init(professional: Professional) {
        self.professional = professional
        let id = professional.id
        _patients = Query(
            filter: #Predicate<Patient> { $0.professional?.id == id && $0.deletedAt == nil }
        )
    }

    var body: some View {
        Group {
            if patients.isEmpty {
                // Empty state cuando no hay pacientes registrados
                ContentUnavailableView(
                    "Sin datos",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Agregá pacientes para ver las estadísticas de tu práctica.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {

                        // MARK: - KPI Cards
                        kpiSection

                        // MARK: - Distribución por Género
                        if !viewModel.genderDistribution.isEmpty {
                            chartSection("Distribución por Género", systemImage: "person.2") {
                                genderChart
                            }
                        }

                        // MARK: - Distribución por Edad
                        chartSection("Distribución por Edad", systemImage: "calendar.badge.clock") {
                            ageChart
                        }

                        // MARK: - Top 5 Diagnósticos
                        if !viewModel.topDiagnoses.isEmpty {
                            chartSection("Top Diagnósticos", systemImage: "stethoscope") {
                                topDiagnosesChart
                            }
                        }

                        // MARK: - Sesiones en el Tiempo
                        if !viewModel.sessionsOverTime.isEmpty {
                            chartSection("Sesiones en el Tiempo", systemImage: "chart.line.uptrend.xyaxis") {
                                sessionsTimeChart
                            }
                        }

                        // MARK: - Sesiones por Modalidad
                        if !viewModel.sessionsByModality.isEmpty {
                            chartSection("Sesiones por Modalidad", systemImage: "person.2.wave.2") {
                                modalityChart
                            }
                        }

                        // MARK: - Sesiones por Estado
                        if !viewModel.sessionsByStatus.isEmpty {
                            chartSection("Sesiones por Estado", systemImage: "checkmark.circle") {
                                statusChart
                            }
                        }

                        // MARK: - Factores de Riesgo
                        chartSection("Factores de Riesgo", systemImage: "exclamationmark.triangle") {
                            lifestyleChart
                        }

                        // MARK: - Antecedentes Familiares
                        chartSection("Antecedentes Familiares", systemImage: "figure.2.and.child.holdinghands") {
                            familyHistoryChart
                        }

                        // MARK: - Crecimiento de Pacientes
                        if viewModel.patientGrowth.count >= 2 {
                            chartSection("Crecimiento de la Práctica", systemImage: "arrow.up.right") {
                                patientGrowthChart
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshToken) {
            viewModel.loadStatistics(from: patients)
        }
    }

    // MARK: - KPI Cards

    private var kpiSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            KPICard(
                title: "Pacientes",
                value: "\(viewModel.totalPatients)",
                systemImage: "person.2",
                color: .blue
            )
            KPICard(
                title: "Sesiones del Mes",
                value: "\(viewModel.sessionsThisMonth)",
                systemImage: "calendar",
                color: .green
            )
            KPICard(
                title: "Duración Promedio",
                value: "\(Int(viewModel.averageDurationMinutes)) min",
                systemImage: "clock",
                color: .orange
            )
            KPICard(
                title: "Tasa Completado",
                value: String(format: "%.0f%%", viewModel.completionRate),
                systemImage: "checkmark.circle",
                color: .purple
            )
        }
    }

    private var refreshToken: String {
        let patientCount = patients.count
        let latestSessionUpdate = patients
            .flatMap { $0.sessions ?? [] }
            .map(\.updatedAt.timeIntervalSince1970)
            .max() ?? 0
        let activeDiagnosisCount = patients
            .flatMap { $0.activeDiagnoses ?? [] }
            .count

        return "\(patientCount)-\(latestSessionUpdate)-\(activeDiagnosisCount)"
    }

    // MARK: - Género (Donut)

    private var genderChart: some View {
        VStack(spacing: 12) {
            Chart(viewModel.genderDistribution) { segment in
                SectorMark(
                    angle: .value("Cantidad", segment.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(segment.color)
                .cornerRadius(4)
            }
            .frame(height: 180)

            // Leyenda horizontal
            chartLegend(viewModel.genderDistribution)
        }
    }

    // MARK: - Edad (Barras verticales)

    private var ageChart: some View {
        Chart(viewModel.ageRangeDistribution) { bar in
            BarMark(
                x: .value("Rango", bar.label),
                y: .value("Cantidad", bar.value)
            )
            .foregroundStyle(.tint)
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 180)
    }

    // MARK: - Top Diagnósticos (Barras horizontales)

    private var topDiagnosesChart: some View {
        Chart(viewModel.topDiagnoses) { bar in
            BarMark(
                x: .value("Cantidad", bar.value),
                y: .value("Diagnóstico", bar.label)
            )
            .foregroundStyle(.tint)
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(Int(bar.value))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.caption)
            }
        }
        // Altura dinámica según cantidad de diagnósticos
        .frame(height: CGFloat(viewModel.topDiagnoses.count) * 44)
    }

    // MARK: - Sesiones en el Tiempo (Línea con series por status)

    private var sessionsTimeChart: some View {
        VStack(spacing: 12) {
            // Picker de período temporal
            Picker("Período", selection: $viewModel.sessionTimePeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            Chart(viewModel.sessionsOverTime) { point in
                LineMark(
                    x: .value("Fecha", point.date),
                    y: .value("Sesiones", point.value),
                    series: .value("Estado", point.series)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Estado", point.series))

                PointMark(
                    x: .value("Fecha", point.date),
                    y: .value("Sesiones", point.value)
                )
                .foregroundStyle(by: .value("Estado", point.series))
            }
            .chartForegroundStyleScale([
                "Completadas": Color.green,
                "Canceladas": Color.red,
                "Programadas": Color.blue,
            ])
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
        }
    }

    // MARK: - Modalidad (Donut)

    private var modalityChart: some View {
        VStack(spacing: 12) {
            Chart(viewModel.sessionsByModality) { segment in
                SectorMark(
                    angle: .value("Cantidad", segment.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(segment.color)
                .cornerRadius(4)
            }
            .frame(height: 180)

            chartLegend(viewModel.sessionsByModality)
        }
    }

    // MARK: - Status (Donut)

    private var statusChart: some View {
        VStack(spacing: 12) {
            Chart(viewModel.sessionsByStatus) { segment in
                SectorMark(
                    angle: .value("Cantidad", segment.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(segment.color)
                .cornerRadius(4)
            }
            .frame(height: 180)

            chartLegend(viewModel.sessionsByStatus)
        }
    }

    // MARK: - Factores de Riesgo (Barras horizontales con %)

    private var lifestyleChart: some View {
        Chart(viewModel.lifestyleFactors) { bar in
            BarMark(
                x: .value("Porcentaje", bar.value),
                y: .value("Factor", bar.label)
            )
            .foregroundStyle(.orange)
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text(String(format: "%.0f%%", bar.value))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: CGFloat(viewModel.lifestyleFactors.count) * 44)
    }

    // MARK: - Antecedentes Familiares (Barras horizontales)

    private var familyHistoryChart: some View {
        Chart(viewModel.familyHistoryPrevalence) { bar in
            BarMark(
                x: .value("Pacientes", bar.value),
                y: .value("Antecedente", bar.label)
            )
            .foregroundStyle(.red.opacity(0.7))
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(Int(bar.value))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: CGFloat(viewModel.familyHistoryPrevalence.count) * 40)
    }

    // MARK: - Crecimiento de Pacientes (Línea + Área)

    private var patientGrowthChart: some View {
        Chart(viewModel.patientGrowth) { point in
            AreaMark(
                x: .value("Fecha", point.date),
                y: .value("Pacientes", point.value)
            )
            .foregroundStyle(.tint.opacity(0.15))

            LineMark(
                x: .value("Fecha", point.date),
                y: .value("Pacientes", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.tint)

            PointMark(
                x: .value("Fecha", point.date),
                y: .value("Pacientes", point.value)
            )
            .foregroundStyle(.tint)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 180)
    }

    // MARK: - Componentes reutilizables

    /// Wrapper para cada sección de gráfico con fondo material y header
    private func chartSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Leyenda horizontal para donut charts
    private func chartLegend(_ segments: [ChartSegment]) -> some View {
        // Wrap horizontal para que se ajuste si hay muchos items
        HStack(spacing: 16) {
            ForEach(segments) { segment in
                HStack(spacing: 4) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 8, height: 8)
                    Text("\(segment.label) (\(segment.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - KPI Card

/// Tarjeta compacta para mostrar un KPI principal del dashboard
private struct KPICard: View {

    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title.bold())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("Dashboard con datos") {
    NavigationStack {
        DashboardView(
            professional: Professional(
                fullName: "Dr. Juan Pérez",
                specialty: "Psicología"
            )
        )
    }
}

