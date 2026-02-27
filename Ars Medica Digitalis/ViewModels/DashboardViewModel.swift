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

/// Actividad de pacientes por período:
/// - activos al cierre del bucket temporal
/// - altas del período
/// - bajas del período
struct PatientActivityPoint: Identifiable {
    let id = UUID()
    let bucketStart: Date
    let activePatients: Int
    let admissions: Int
    let discharges: Int
}

enum PatientActivityPeriod: String, CaseIterable {
    case day = "Día"
    case week = "Semana"
    case month = "Mes"
    case year = "Año"
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

    /// Variante que recibe directamente la lista de pacientes del profesional
    /// (activos e inactivos para poder calcular altas/bajas).
    /// Evita depender de la relación inversa `professional.patients` que puede no estar faulted.
    func loadStatistics(from allPatients: [Patient]) {
        let activePatients = allPatients.filter(\.isActive)
        allPatientsCache = allPatients
        totalPatients = activePatients.count
        // Recolectar todas las sesiones una sola vez
        allSessions = activePatients.flatMap { $0.sessions ?? [] }

        computeKPIs()
        computeGenderDistribution(activePatients)
        computeAgeRangeDistribution(activePatients)
        computeTopDiagnoses(activePatients)
        recomputeSessionsOverTime()
        computeSessionsByModality()
        computeSessionsByStatus()
        computeLifestyleFactors(activePatients)
        computeFamilyHistoryPrevalence(activePatients)
        computePatientGrowth(activePatients)
        recomputePatientActivity()
    }

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
    private(set) var patientActivity: [PatientActivityPoint] = []

    // MARK: - Picker de período temporal

    /// Al cambiar el período se recomputan las sesiones por tiempo
    var sessionTimePeriod: TimePeriod = .months {
        didSet { recomputeSessionsOverTime() }
    }

    /// Período del gráfico de actividad de pacientes (altas/bajas/activos)
    var patientActivityPeriod: PatientActivityPeriod = .month {
        didSet { recomputePatientActivity() }
    }

    // Cache interna de sesiones para recomputar sin re-traversar todo el grafo
    private var allSessions: [Session] = []
    // Cache interna de pacientes para recomputar actividad sin recargar todo
    private var allPatientsCache: [Patient] = []

    // MARK: - Carga principal

    /// Recorre el grafo completo del profesional y computa todas las estadísticas.
    /// Se llama una vez en .onAppear de DashboardView.
    func loadStatistics(for professional: Professional) {
        let allPatients = professional.patients ?? []
        let activePatients = allPatients.filter(\.isActive)
        allPatientsCache = allPatients
        totalPatients = activePatients.count

        // Recolectar todas las sesiones una sola vez
        allSessions = activePatients.flatMap { $0.sessions ?? [] }

        computeKPIs()
        computeGenderDistribution(activePatients)
        computeAgeRangeDistribution(activePatients)
        computeTopDiagnoses(activePatients)
        recomputeSessionsOverTime()
        computeSessionsByModality()
        computeSessionsByStatus()
        computeLifestyleFactors(activePatients)
        computeFamilyHistoryPrevalence(activePatients)
        computePatientGrowth(activePatients)
        recomputePatientActivity()
    }

    // MARK: - KPIs

    private func computeKPIs() {
        let calendar = Calendar.current
        let now = Date()

        // Sesiones del mes actual
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        sessionsThisMonth = allSessions.filter { $0.sessionDate >= startOfMonth && $0.sessionDate <= now }.count

        // Duración promedio de sesiones completadas
        let completed = allSessions.filter { $0.sessionStatusValue == .completada }
        if completed.isEmpty {
            averageDurationMinutes = 0
        } else {
            let totalMinutes = completed.reduce(0) { $0 + $1.durationMinutes }
            averageDurationMinutes = Double(totalMinutes) / Double(completed.count)
        }

        // Tasa de completado: completadas / total (excluyendo programadas futuras)
        let nonScheduled = allSessions.filter { $0.sessionStatusValue != .programada }
        if nonScheduled.isEmpty {
            completionRate = 0
        } else {
            let completedCount = nonScheduled.filter { $0.sessionStatusValue == .completada }.count
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
            let title = diagnosis.displayTitle
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
        SessionStatusMapping(sessionStatusRawValue: status)?.pluralLabel
        ?? status.capitalized
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
        if let mapping = SessionTypeMapping(sessionTypeRawValue: type) {
            return (mapping.label, mapping.tint)
        }
        return (type.capitalized, .secondary)
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
        if let mapping = SessionStatusMapping(sessionStatusRawValue: status) {
            return (mapping.pluralLabel, mapping.tint)
        }
        return (status.capitalized, .secondary)
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

    // MARK: - Actividad por período (Altas/Bajas/Activos)

    private func recomputePatientActivity() {
        computePatientActivity(allPatientsCache, period: patientActivityPeriod)
    }

    /// Serie temporal para visualizar:
    /// - altas (createdAt)
    /// - bajas (deletedAt)
    /// - pacientes activos al cierre de cada bucket
    private func computePatientActivity(_ allPatients: [Patient], period: PatientActivityPeriod) {
        let calendar = Calendar.current
        guard !allPatients.isEmpty else {
            patientActivity = []
            return
        }

        let earliestCreated = allPatients.map(\.createdAt).min() ?? Date()
        let latestDeleted = allPatients.compactMap(\.deletedAt).max() ?? Date.distantPast
        let latestCreated = allPatients.map(\.createdAt).max() ?? Date.distantPast
        let endReference = max(Date(), latestDeleted, latestCreated)

        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }

        guard
            let startBucket = calendar.dateInterval(of: component, for: earliestCreated)?.start,
            let endBucket = calendar.dateInterval(of: component, for: endReference)?.start
        else {
            patientActivity = []
            return
        }

        var cursor = startBucket
        var points: [PatientActivityPoint] = []

        while cursor <= endBucket {
            guard let nextBucket = calendar.date(byAdding: component, value: 1, to: cursor) else { break }

            let admissions = allPatients.filter { patient in
                patient.createdAt >= cursor && patient.createdAt < nextBucket
            }.count

            let discharges = allPatients.filter { patient in
                guard let deletedAt = patient.deletedAt else { return false }
                return deletedAt >= cursor && deletedAt < nextBucket
            }.count

            // Activos al cierre del bucket (inicio del siguiente).
            let activeAtBucketClose = allPatients.filter { patient in
                guard patient.createdAt < nextBucket else { return false }
                guard let deletedAt = patient.deletedAt else { return true }
                return deletedAt >= nextBucket
            }.count

            points.append(
                PatientActivityPoint(
                    bucketStart: cursor,
                    activePatients: activeAtBucketClose,
                    admissions: admissions,
                    discharges: discharges
                )
            )

            cursor = nextBucket
        }

        patientActivity = points
    }
}
