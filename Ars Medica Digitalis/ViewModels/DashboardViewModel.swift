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
    let label: String
    let count: Int
    let color: Color

    var id: String { label }
}

/// Barra para BarMark horizontal/vertical
struct ChartBar: Identifiable {
    let label: String
    let value: Double

    var id: String { label }
}

/// Punto temporal para LineMark / AreaMark
struct ChartTimePoint: Identifiable {
    let date: Date
    let value: Int
    let series: String

    var id: String { "\(date.timeIntervalSinceReferenceDate)|\(series)" }
}

/// Actividad de pacientes por período:
/// - activos al cierre del bucket temporal
/// - altas del período
/// - bajas del período
struct PatientActivityPoint: Identifiable {
    let bucketStart: Date
    let activePatients: Int
    let admissions: Int
    let discharges: Int

    var id: TimeInterval { bucketStart.timeIntervalSinceReferenceDate }
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

    /// **Función canónica de cómputo estadístico.**
    ///
    /// Recibe la lista completa de pacientes (activos e inactivos) y actualiza
    /// todos los KPIs y distribuciones del dashboard en memoria, sin requerir
    /// `ModelContext` ni `FetchDescriptor`. Apta para llamarse en tests unitarios
    /// pasando directamente un array de objetos.
    ///
    /// `loadStatistics(for:)` es un alias de conveniencia que extrae los pacientes
    /// del profesional y delega aquí. Toda la lógica de cómputo vive en este método.
    func loadStatistics(from allPatients: [Patient]) {
        let activePatients = allPatients.filter(\.isActive)
        allPatientsCache = allPatients
        totalPatients = activePatients.count
        // Recolectar todas las sesiones una sola vez
        allSessions = activePatients.flatMap { $0.sessions ?? [] }

        computeSessionAggregates()
        computeGenderDistribution(activePatients)
        computeAgeRangeDistribution(activePatients)
        computeTopDiagnoses(activePatients)
        recomputeSessionsOverTime()
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

    /// Variante de conveniencia que extrae los pacientes del profesional y delega.
    /// `loadStatistics(from:)` es la única fuente de verdad del cómputo.
    func loadStatistics(for professional: Professional) {
        loadStatistics(from: professional.patients ?? [])
    }

    // MARK: - Agregados de sesiones (KPIs + modalidad + estado en un solo pase)

    /// Un único recorrido sobre `allSessions` que computa simultáneamente KPIs,
    /// distribución por modalidad y distribución por estado.
    /// Evita tres iteraciones independientes sobre la misma colección.
    private func computeSessionAggregates() {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            ?? calendar.startOfDay(for: now)

        var monthCount = 0
        var completedDuration = 0
        var completedCount = 0
        var nonScheduledCount = 0
        var completedNonScheduledCount = 0
        var modalityCounts: [String: Int] = [:]
        var statusCounts: [String: Int] = [:]

        for session in allSessions {
            let sv = session.sessionStatusValue

            if session.sessionDate >= startOfMonth && session.sessionDate <= now {
                monthCount += 1
            }

            if sv == .completada {
                completedDuration += session.durationMinutes
                completedCount += 1
            }

            if sv != .programada {
                nonScheduledCount += 1
                if sv == .completada { completedNonScheduledCount += 1 }
            }

            modalityCounts[session.sessionType, default: 0] += 1
            statusCounts[session.status, default: 0] += 1
        }

        sessionsThisMonth = monthCount
        averageDurationMinutes = completedCount > 0
            ? Double(completedDuration) / Double(completedCount)
            : 0
        completionRate = nonScheduledCount > 0
            ? (Double(completedNonScheduledCount) / Double(nonScheduledCount)) * 100
            : 0

        sessionsByModality = modalityCounts.map { type, count in
            let (label, color) = modalityLabelColor(type)
            return ChartSegment(label: label, count: count, color: color)
        }.sorted { $0.count > $1.count }

        sessionsByStatus = statusCounts.map { status, count in
            let (label, color) = statusLabelColor(status)
            return ChartSegment(label: label, count: count, color: color)
        }.sorted { $0.count > $1.count }
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

    private func modalityLabelColor(_ type: String) -> (String, Color) {
        if let mapping = SessionTypeMapping(sessionTypeRawValue: type) {
            return (mapping.label, mapping.tint)
        }
        return (type.capitalized, .secondary)
    }

    private func statusLabelColor(_ status: String) -> (String, Color) {
        if let mapping = SessionStatusMapping(sessionStatusRawValue: status) {
            return (mapping.pluralLabel, mapping.tint)
        }
        return (status.capitalized, .secondary)
    }

    // MARK: - Factores de Estilo de Vida

    /// Porcentaje de pacientes con cada factor activo (0–100)
    /// Un único pase sobre `patients` en lugar de cuatro `.filter` independientes.
    private func computeLifestyleFactors(_ patients: [Patient]) {
        guard !patients.isEmpty else {
            lifestyleFactors = []
            return
        }

        var smoking = 0, alcohol = 0, drugs = 0, checkups = 0
        for patient in patients {
            if patient.smokingStatus  { smoking  += 1 }
            if patient.alcoholUse     { alcohol  += 1 }
            if patient.drugUse        { drugs    += 1 }
            if patient.routineCheckups { checkups += 1 }
        }

        let total = Double(patients.count)
        lifestyleFactors = [
            ChartBar(label: "Tabaquismo", value: (Double(smoking)  / total) * 100),
            ChartBar(label: "Alcohol",    value: (Double(alcohol)  / total) * 100),
            ChartBar(label: "Drogas",     value: (Double(drugs)    / total) * 100),
            ChartBar(label: "Chequeos",   value: (Double(checkups) / total) * 100),
        ]
    }

    // MARK: - Prevalencia de Antecedentes Familiares

    /// Conteo absoluto de pacientes con cada antecedente familiar activo.
    /// Un único pase sobre `patients` en lugar de seis `.filter` independientes.
    private func computeFamilyHistoryPrevalence(_ patients: [Patient]) {
        var hta = 0, acv = 0, cancer = 0, diabetes = 0, heart = 0, mental = 0
        for patient in patients {
            if patient.familyHistoryHTA          { hta     += 1 }
            if patient.familyHistoryACV          { acv     += 1 }
            if patient.familyHistoryCancer       { cancer  += 1 }
            if patient.familyHistoryDiabetes     { diabetes += 1 }
            if patient.familyHistoryHeartDisease { heart   += 1 }
            if patient.familyHistoryMentalHealth { mental  += 1 }
        }
        familyHistoryPrevalence = [
            ChartBar(label: "HTA",          value: Double(hta)),
            ChartBar(label: "ACV",          value: Double(acv)),
            ChartBar(label: "Cáncer",       value: Double(cancer)),
            ChartBar(label: "Diabetes",     value: Double(diabetes)),
            ChartBar(label: "Cardiopatía",  value: Double(heart)),
            ChartBar(label: "Salud mental", value: Double(mental)),
        ]
    }

    // MARK: - Crecimiento de Pacientes

    /// Línea acumulativa de altas de pacientes agrupadas por mes
    private func computePatientGrowth(_ patients: [Patient]) {
        let calendar = Calendar.current

        // Agrupar por inicio de mes
        var monthlyCounts: [Date: Int] = [:]
        for patient in patients {
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: patient.createdAt))
                ?? calendar.startOfDay(for: patient.createdAt)
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
