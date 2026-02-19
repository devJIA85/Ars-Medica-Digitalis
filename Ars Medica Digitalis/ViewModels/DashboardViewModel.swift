//
//  DashboardViewModel.swift
//  Ars Medica Digitalis
//
//  ViewModel del Dashboard de estadísticas del profesional.
//  Recorre el grafo Professional.patients → sessions/diagnoses
//  en memoria (sin FetchDescriptor) — suficiente para prácticas
//  típicas (<500 pacientes). No requiere ModelContext.
//

import SwiftUI

// MARK: - Structs auxiliares para alimentar gráficos

/// Segmento para SectorMark (donut charts)
struct ChartSegment: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let color: Color
}

/// Barra para BarMark horizontal/vertical
struct ChartBar: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

/// Punto temporal para LineMark / AreaMark
struct ChartTimePoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
    let series: String
}

// MARK: - Período temporal para agrupar sesiones

enum TimePeriod: String, CaseIterable {
    case days = "Días"
    case weeks = "Semanas"
    case months = "Meses"
}

// MARK: - ViewModel

@Observable
final class DashboardViewModel {

    // MARK: - KPIs

    private(set) var totalPatients: Int = 0
    private(set) var sessionsThisMonth: Int = 0
    private(set) var averageDurationMinutes: Double = 0
    /// Porcentaje de sesiones completadas sobre el total (0–100)
    private(set) var completionRate: Double = 0

    // MARK: - Gráficos

    private(set) var genderDistribution: [ChartSegment] = []
    private(set) var ageRangeDistribution: [ChartBar] = []
    private(set) var topDiagnoses: [ChartBar] = []
    private(set) var sessionsOverTime: [ChartTimePoint] = []
    private(set) var sessionsByModality: [ChartSegment] = []
    private(set) var sessionsByStatus: [ChartSegment] = []
    private(set) var lifestyleFactors: [ChartBar] = []
    private(set) var familyHistoryPrevalence: [ChartBar] = []
    private(set) var patientGrowth: [ChartTimePoint] = []

    // MARK: - Picker de período temporal

    /// Al cambiar el período se recomputan las sesiones por tiempo
    var sessionTimePeriod: TimePeriod = .months {
        didSet { recomputeSessionsOverTime() }
    }

    // Cache interna de sesiones para recomputar sin re-traversar todo el grafo
    private var allSessions: [Session] = []

    // MARK: - Carga principal

    /// Recorre el grafo completo del profesional y computa todas las estadísticas.
    /// Se llama una vez en .onAppear de DashboardView.
    func loadStatistics(for professional: Professional) {
        let patients = (professional.patients ?? []).filter { $0.isActive }
        totalPatients = patients.count

        // Recolectar todas las sesiones una sola vez
        allSessions = patients.flatMap { $0.sessions ?? [] }

        computeKPIs()
        computeGenderDistribution(patients)
        computeAgeRangeDistribution(patients)
        computeTopDiagnoses(patients)
        recomputeSessionsOverTime()
        computeSessionsByModality()
        computeSessionsByStatus()
        computeLifestyleFactors(patients)
        computeFamilyHistoryPrevalence(patients)
        computePatientGrowth(patients)
    }

    // MARK: - KPIs

    private func computeKPIs() {
        let calendar = Calendar.current
        let now = Date()

        // Sesiones del mes actual
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        sessionsThisMonth = allSessions.filter { $0.sessionDate >= startOfMonth && $0.sessionDate <= now }.count

        // Duración promedio de sesiones completadas
        let completed = allSessions.filter { $0.status == "completada" }
        if completed.isEmpty {
            averageDurationMinutes = 0
        } else {
            let totalMinutes = completed.reduce(0) { $0 + $1.durationMinutes }
            averageDurationMinutes = Double(totalMinutes) / Double(completed.count)
        }

        // Tasa de completado: completadas / total (excluyendo programadas futuras)
        let nonScheduled = allSessions.filter { $0.status != "programada" }
        if nonScheduled.isEmpty {
            completionRate = 0
        } else {
            let completedCount = nonScheduled.filter { $0.status == "completada" }.count
            completionRate = (Double(completedCount) / Double(nonScheduled.count)) * 100
        }
    }

    // MARK: - Distribución por Género

    private func computeGenderDistribution(_ patients: [Patient]) {
        // Se usa gender primero, fallback a biologicalSex
        var counts: [String: Int] = [:]
        for patient in patients {
            let raw = patient.gender.isEmpty ? patient.biologicalSex : patient.gender
            let key = raw.lowercased()
            counts[key, default: 0] += 1
        }

        genderDistribution = counts.map { key, count in
            let (label, color) = genderLabelColor(key)
            return ChartSegment(label: label, count: count, color: color)
        }
        .sorted { $0.count > $1.count }
    }

    /// Mapeo de género a label localizado y color visual
    private func genderLabelColor(_ key: String) -> (String, Color) {
        switch key {
        case "masculino": ("Masculino", .blue)
        case "femenino": ("Femenino", .pink)
        case "no binario": ("No binario", .purple)
        case "intersexual": ("Intersexual", .purple)
        default: ("Otro", .secondary)
        }
    }

    // MARK: - Distribución por Edad

    private func computeAgeRangeDistribution(_ patients: [Patient]) {
        // Buckets clínicamente relevantes
        let buckets: [(label: String, range: ClosedRange<Int>)] = [
            ("0–17", 0...17),
            ("18–25", 18...25),
            ("26–35", 26...35),
            ("36–45", 36...45),
            ("46–55", 46...55),
            ("56–65", 56...65),
            ("65+", 66...200)
        ]

        var counts: [String: Int] = [:]
        for bucket in buckets {
            counts[bucket.label] = 0
        }

        for patient in patients {
            let age = patient.age
            for bucket in buckets where bucket.range.contains(age) {
                counts[bucket.label, default: 0] += 1
                break
            }
        }

        // Mantener orden de buckets (no alfabético)
        ageRangeDistribution = buckets.map { bucket in
            ChartBar(label: bucket.label, value: Double(counts[bucket.label] ?? 0))
        }
    }

    // MARK: - Top 5 Diagnósticos

    private func computeTopDiagnoses(_ patients: [Patient]) {
        // Recolectar todos los diagnósticos vigentes (activeDiagnoses)
        let allDiagnoses = patients.flatMap { $0.activeDiagnoses ?? [] }

        // Agrupar por código CIE-11
        var grouped: [String: (title: String, count: Int)] = [:]
        for diagnosis in allDiagnoses {
            let code = diagnosis.icdCode
            guard !code.isEmpty else { continue }
            // Preferir título en español, fallback a inglés
            let title = diagnosis.icdTitleEs.isEmpty ? diagnosis.icdTitle : diagnosis.icdTitleEs
            let displayLabel = "\(code) — \(title)"
            if let existing = grouped[code] {
                grouped[code] = (existing.title, existing.count + 1)
            } else {
                grouped[code] = (displayLabel, 1)
            }
        }

        // Ordenar por frecuencia descendente, top 5
        topDiagnoses = grouped.values
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { ChartBar(label: $0.title, value: Double($0.count)) }
    }

    // MARK: - Sesiones por Tiempo

    /// Recomputa el gráfico de sesiones agrupadas por el período seleccionado.
    /// Se llama al cambiar sessionTimePeriod y al cargar datos.
    private func recomputeSessionsOverTime() {
        let calendar = Calendar.current

        // Determinar el componente de Calendar según el período
        let component: Calendar.Component
        switch sessionTimePeriod {
        case .days: component = .day
        case .weeks: component = .weekOfYear
        case .months: component = .month
        }

        // Agrupar sesiones por fecha normalizada y status
        var grouped: [Date: [String: Int]] = [:]

        for session in allSessions {
            let normalized = calendar.dateInterval(of: component, for: session.sessionDate)?.start ?? session.sessionDate
            grouped[normalized, default: [:]][session.status, default: 0] += 1
        }

        // Convertir a puntos temporales con series por status
        var points: [ChartTimePoint] = []
        for (date, statusCounts) in grouped {
            for (status, count) in statusCounts {
                let seriesLabel = statusDisplayLabel(status)
                points.append(ChartTimePoint(date: date, value: count, series: seriesLabel))
            }
        }

        sessionsOverTime = points.sorted { $0.date < $1.date }
    }

    /// Label legible para status de sesión
    private func statusDisplayLabel(_ status: String) -> String {
        switch status {
        case "completada": "Completadas"
        case "cancelada": "Canceladas"
        case "programada": "Programadas"
        default: status.capitalized
        }
    }

    // MARK: - Sesiones por Modalidad

    private func computeSessionsByModality() {
        var counts: [String: Int] = [:]
        for session in allSessions {
            counts[session.sessionType, default: 0] += 1
        }

        sessionsByModality = counts.map { type, count in
            let (label, color) = modalityLabelColor(type)
            return ChartSegment(label: label, count: count, color: color)
        }
        .sorted { $0.count > $1.count }
    }

    private func modalityLabelColor(_ type: String) -> (String, Color) {
        switch type {
        case "presencial": ("Presencial", .teal)
        case "videollamada": ("Videollamada", .indigo)
        case "telefónica": ("Telefónica", .orange)
        default: (type.capitalized, .secondary)
        }
    }

    // MARK: - Sesiones por Status

    private func computeSessionsByStatus() {
        var counts: [String: Int] = [:]
        for session in allSessions {
            counts[session.status, default: 0] += 1
        }

        sessionsByStatus = counts.map { status, count in
            let (label, color) = statusLabelColor(status)
            return ChartSegment(label: label, count: count, color: color)
        }
        .sorted { $0.count > $1.count }
    }

    private func statusLabelColor(_ status: String) -> (String, Color) {
        switch status {
        case "completada": ("Completadas", .green)
        case "cancelada": ("Canceladas", .red)
        case "programada": ("Programadas", .blue)
        default: (status.capitalized, .secondary)
        }
    }

    // MARK: - Factores de Estilo de Vida

    /// Porcentaje de pacientes con cada factor activo (0–100)
    private func computeLifestyleFactors(_ patients: [Patient]) {
        guard !patients.isEmpty else {
            lifestyleFactors = []
            return
        }

        let total = Double(patients.count)
        let smoking = Double(patients.filter(\.smokingStatus).count)
        let alcohol = Double(patients.filter(\.alcoholUse).count)
        let drugs = Double(patients.filter(\.drugUse).count)
        let checkups = Double(patients.filter(\.routineCheckups).count)

        lifestyleFactors = [
            ChartBar(label: "Tabaquismo", value: (smoking / total) * 100),
            ChartBar(label: "Alcohol", value: (alcohol / total) * 100),
            ChartBar(label: "Drogas", value: (drugs / total) * 100),
            ChartBar(label: "Chequeos", value: (checkups / total) * 100),
        ]
    }

    // MARK: - Prevalencia de Antecedentes Familiares

    /// Conteo absoluto de pacientes con cada antecedente familiar activo
    private func computeFamilyHistoryPrevalence(_ patients: [Patient]) {
        familyHistoryPrevalence = [
            ChartBar(label: "HTA", value: Double(patients.filter(\.familyHistoryHTA).count)),
            ChartBar(label: "ACV", value: Double(patients.filter(\.familyHistoryACV).count)),
            ChartBar(label: "Cáncer", value: Double(patients.filter(\.familyHistoryCancer).count)),
            ChartBar(label: "Diabetes", value: Double(patients.filter(\.familyHistoryDiabetes).count)),
            ChartBar(label: "Cardiopatía", value: Double(patients.filter(\.familyHistoryHeartDisease).count)),
            ChartBar(label: "Salud mental", value: Double(patients.filter(\.familyHistoryMentalHealth).count)),
        ]
    }

    // MARK: - Crecimiento de Pacientes

    /// Línea acumulativa de altas de pacientes agrupadas por mes
    private func computePatientGrowth(_ patients: [Patient]) {
        let calendar = Calendar.current

        // Agrupar por inicio de mes
        var monthlyCounts: [Date: Int] = [:]
        for patient in patients {
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: patient.createdAt))!
            monthlyCounts[startOfMonth, default: 0] += 1
        }

        // Ordenar cronológicamente y acumular
        let sorted = monthlyCounts.sorted { $0.key < $1.key }
        var accumulated = 0
        var points: [ChartTimePoint] = []

        for (date, count) in sorted {
            accumulated += count
            points.append(ChartTimePoint(date: date, value: accumulated, series: "Pacientes"))
        }

        patientGrowth = points
    }
}
