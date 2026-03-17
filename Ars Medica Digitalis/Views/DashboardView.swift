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
            filter: #Predicate<Patient> { $0.professional?.id == id }
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
                    // Un único GlassEffectContainer agrupa todos los CardContainer hijos,
                    // permitiendo al sistema compartir un solo pase de backdrop sampling
                    // en lugar de calcular N backdrops individuales para cada card.
                    GlassEffectContainer {
                    LazyVStack(spacing: AppSpacing.md) {

                        // MARK: - KPI Cards
                        kpiSection

                        // MARK: - Actividad de Pacientes (Activos + Altas + Bajas)
                        if !viewModel.patientActivity.isEmpty {
                            chartSection("Actividad de Pacientes", systemImage: "person.3.sequence") {
                                patientActivityChart
                            }
                        }

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
                    } // GlassEffectContainer
                    .backgroundExtensionEffect()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .navigationTitle("Dashboard Clínico")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshToken) {
            viewModel.loadStatistics(from: patients)
        }
    }

    // MARK: - KPI Cards

    private var kpiSection: some View {
        CardContainer(style: .flat) {
            SectionContainer(title: "Resumen de la práctica", systemImage: "heart.text.square") {
                VStack(spacing: 0) {
                    HealthMetricRow(
                        title: "Pacientes activos",
                        value: "\(viewModel.totalPatients)",
                        systemImage: "person.2.fill",
                        color: .blue
                    )
                    Divider()
                    HealthMetricRow(
                        title: "Sesiones del mes",
                        value: "\(viewModel.sessionsThisMonth)",
                        systemImage: "calendar",
                        color: .green
                    )
                    Divider()
                    HealthMetricRow(
                        title: "Duración promedio",
                        value: "\(Int(viewModel.averageDurationMinutes)) min",
                        systemImage: "clock.fill",
                        color: .orange
                    )
                    Divider()
                    HealthMetricRow(
                        title: "Tasa completado",
                        value: String(format: "%.0f%%", viewModel.completionRate),
                        systemImage: "checkmark.circle.fill",
                        color: .purple
                    )
                }
                .padding(.top, 2)
            }
        }
    }

    private var refreshToken: String {
        let patientCount = patients.count
        let deletedPatients = patients.filter { $0.deletedAt != nil }.count
        let latestPatientUpdate = patients
            .map(\.updatedAt.timeIntervalSince1970)
            .max() ?? 0
        let latestSessionUpdate = patients
            .flatMap { $0.sessions ?? [] }
            .map(\.updatedAt.timeIntervalSince1970)
            .max() ?? 0
        let activeDiagnosisCount = patients
            .flatMap { $0.activeDiagnoses ?? [] }
            .count

        return "\(patientCount)-\(deletedPatients)-\(latestPatientUpdate)-\(latestSessionUpdate)-\(activeDiagnosisCount)"
    }

    // MARK: - Género (Donut)

    private var genderChart: some View {
        VStack(spacing: AppSpacing.sm) {
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
        VStack(spacing: AppSpacing.sm) {
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
        VStack(spacing: AppSpacing.sm) {
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
        VStack(spacing: AppSpacing.sm) {
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

    // MARK: - Actividad de Pacientes (barras + línea)

    private var patientActivityChart: some View {
        VStack(spacing: AppSpacing.sm) {
            Picker("Período", selection: $viewModel.patientActivityPeriod) {
                ForEach(PatientActivityPeriod.allCases, id: \.self) { period in
                    Text(patientActivityPickerLabel(period)).tag(period)
                }
            }
            .pickerStyle(.segmented)

            Chart {
                ForEach(viewModel.patientActivity) { point in
                    BarMark(
                        x: .value("Período", point.bucketStart, unit: patientActivityCalendarUnit),
                        y: .value("Altas", point.admissions),
                        width: .ratio(0.45)
                    )
                    .position(by: .value("Tipo", "Altas"))
                    .foregroundStyle(Color.green.gradient)
                    .annotation(position: .top) {
                        if point.admissions > 0 {
                            Text("\(point.admissions)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    BarMark(
                        x: .value("Período", point.bucketStart, unit: patientActivityCalendarUnit),
                        y: .value("Bajas", point.discharges),
                        width: .ratio(0.45)
                    )
                    .position(by: .value("Tipo", "Bajas"))
                    .foregroundStyle(Color.red.opacity(0.75))
                    .annotation(position: .top) {
                        if point.discharges > 0 {
                            Text("\(point.discharges)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LineMark(
                        x: .value("Período", point.bucketStart, unit: patientActivityCalendarUnit),
                        y: .value("Activos", point.activePatients)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Período", point.bucketStart, unit: patientActivityCalendarUnit),
                        y: .value("Activos", point.activePatients)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: patientActivityDesiredTicks)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(patientActivityAxisLabel(for: date))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)

            HStack(spacing: AppSpacing.md) {
                chartMiniLegendItem("Activos", color: .blue)
                chartMiniLegendItem("Altas", color: .green)
                chartMiniLegendItem("Bajas", color: .red)
            }
        }
    }

    private var patientActivityCalendarUnit: Calendar.Component {
        switch viewModel.patientActivityPeriod {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    private var patientActivityDesiredTicks: Int {
        switch viewModel.patientActivityPeriod {
        case .day: return 7
        case .week: return 8
        case .month: return 6
        case .year: return 6
        }
    }

    private func patientActivityPickerLabel(_ period: PatientActivityPeriod) -> String {
        switch period {
        case .day: return "Día"
        case .week: return "Sem"
        case .month: return "Mes"
        case .year: return "Año"
        }
    }

    private func patientActivityAxisLabel(for date: Date) -> String {
        let locale = Locale(identifier: "es_AR")
        switch viewModel.patientActivityPeriod {
        case .day:
            return date.formatted(
                Date.FormatStyle()
                    .day(.twoDigits)
                    .month(.abbreviated)
                    .locale(locale)
            )
        case .week:
            let week = Calendar.current.component(.weekOfYear, from: date)
            return "S\(week)"
        case .month:
            return date.formatted(
                Date.FormatStyle()
                    .month(.abbreviated)
                    .locale(locale)
            )
        case .year:
            return date.formatted(
                Date.FormatStyle()
                    .year(.defaultDigits)
                    .locale(locale)
            )
        }
    }

    // MARK: - Componentes reutilizables

    /// Wrapper para cada sección de gráfico con fondo material y header
    private func chartSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        CardContainer(style: .flat) {
            SectionContainer(title: title, systemImage: systemImage) {
                content()
            }
        }
    }

    /// Leyenda horizontal para donut charts
    private func chartLegend(_ segments: [ChartSegment]) -> some View {
        // Wrap horizontal para que se ajuste si hay muchos items
        HStack(spacing: AppSpacing.md) {
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

    private func chartMiniLegendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HealthMetricRow: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(.vertical, AppSpacing.sm)
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
