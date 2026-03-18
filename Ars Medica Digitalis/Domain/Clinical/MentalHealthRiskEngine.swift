//
//  MentalHealthRiskEngine.swift
//  Ars Medica Digitalis
//
//  Motor puro de score clínico para priorización de seguimiento.
//

import Foundation

enum MentalHealthRiskUrgency: String, Sendable, Equatable {
    case routine
    case soon
    case urgent
    case immediate
}

enum MentalHealthRiskPriorityLevel: String, Sendable, Equatable {
    case stable
    case moderate
    case high
    case critical
}

struct MentalHealthRiskScore: Sendable, Equatable {
    let totalScore: Int
    let urgency: MentalHealthRiskUrgency
    let adherenceRisk: Int
    let dropoutRisk: Int
    let priorityLevel: MentalHealthRiskPriorityLevel
}

struct MentalHealthRiskEngine: Sendable {

    // MARK: - Constantes clínicas

    /// Pesos para combinar los dos componentes de riesgo en el score total.
    /// Dropout pondera más porque predice abandono concreto (consecuencia clínica directa);
    /// adherencia pondera menos porque puede estar compensada por continuidad.
    private enum Weights {
        static let adherenceRisk: Double = 0.45
        static let dropoutRisk: Double   = 0.55
    }

    /// Parámetros del componente de riesgo de adherencia.
    private enum AdherenceRisk {
        /// Multiplica (1 - adherencia) para convertirlo en puntos de riesgo (0–70).
        static let baseScaleFactor = 70
        /// Puntos de penalización por cada cancelación registrada.
        static let cancellationPenaltyPerSession = 8
        /// Techo de penalización por cancelaciones (3 cancelaciones = máximo impacto).
        static let cancellationPenaltyCap = 24
        /// Penalización por deuda pendiente: reduce probabilidad de continuidad.
        static let debtPenalty = 8
    }

    /// Parámetros del componente de riesgo de abandono terapéutico.
    private enum DropoutRisk {
        // Inactividad sin historial previo
        /// Sin sesiones previas ni próxima agendada: riesgo basal alto.
        static let noHistoryNoUpcoming  = 35
        /// Sin sesiones previas pero tiene próxima agendada: riesgo moderado.
        static let noHistoryWithUpcoming = 10

        // Inactividad por días transcurridos desde última sesión
        static let inactivityUnder7Days  =  5   // < 7 días: reciente
        static let inactivity7to14Days   = 20   // 7–14 días: en margen
        static let inactivity14to30Days  = 40   // 14–30 días: preocupante
        static let inactivity30to60Days  = 65   // 30–60 días: alto
        static let inactivityOver60Days  = 85   // > 60 días: crítico

        /// Sin sesión próxima agendada: señal fuerte de posible abandono.
        static let noUpcomingPenalty     = 20
        /// Pocos encuentros totales: vínculo terapéutico aún no consolidado.
        static let lowEngagementPenalty  = 10
        /// Umbral para "bajo engagement" (≤ N sesiones totales).
        static let lowEngagementThreshold = 1
        /// Sin diagnóstico registrado: dificulta plan de seguimiento.
        static let noDiagnosisPenalty    =  5
        /// Deuda pendiente: barrera financiera de abandono.
        static let debtPenalty           = 10
    }

    /// Umbrales para derivar nivel de urgencia desde el score total y sub-scores.
    private enum UrgencyThreshold {
        static let immediateScore   = 80  // Score total que activa urgencia máxima
        static let immediateDropout = 85  // Dropout + sin próxima sesión → inmediato
        static let urgentScore      = 60
        static let urgentDropout    = 70
        static let soonScore        = 30
        static let soonAdherence    = 40
    }

    /// Umbrales de corte para niveles de prioridad (score 0–100).
    private enum PriorityThreshold {
        static let stableRange   = 0..<30
        static let moderateRange = 30..<60
        static let highRange     = 60..<80
        // critical: 80+
    }

    // MARK: - API pública

    func computeRisk(snapshot: PatientClinicalSnapshot) -> MentalHealthRiskScore {
        Self.computeRisk(snapshot: snapshot)
    }

    static func computeRisk(snapshot: PatientClinicalSnapshot) -> MentalHealthRiskScore {
        let adherenceRisk = computeAdherenceRisk(snapshot: snapshot)
        let dropoutRisk = computeDropoutRisk(snapshot: snapshot)
        let clinicalModifier = BDISeverityLevel
            .from(rawSeverity: snapshot.bdiSeverity)?
            .clinicalRiskModifier ?? 0
        let totalScore = Self.clamp(
            Int(
                round(
                    (Double(adherenceRisk) * Weights.adherenceRisk)
                    + (Double(dropoutRisk) * Weights.dropoutRisk)
                )
            ) + clinicalModifier,
            lower: 0,
            upper: 100
        )

        return MentalHealthRiskScore(
            totalScore: totalScore,
            urgency: computeUrgency(
                totalScore: totalScore,
                adherenceRisk: adherenceRisk,
                dropoutRisk: dropoutRisk,
                snapshot: snapshot
            ),
            adherenceRisk: adherenceRisk,
            dropoutRisk: dropoutRisk,
            priorityLevel: priorityLevel(for: totalScore)
        )
    }

    static func priorityLevel(for totalScore: Int) -> MentalHealthRiskPriorityLevel {
        let normalizedScore = clamp(totalScore, lower: 0, upper: 100)

        switch normalizedScore {
        case PriorityThreshold.stableRange:
            return .stable
        case PriorityThreshold.moderateRange:
            return .moderate
        case PriorityThreshold.highRange:
            return .high
        default:
            return .critical
        }
    }

    // MARK: - Cómputos privados

    private static func computeAdherenceRisk(snapshot: PatientClinicalSnapshot) -> Int {
        let normalizedAdherence = min(max(snapshot.adherence, 0), 1)
        let baseRisk = Int(round((1 - normalizedAdherence) * Double(AdherenceRisk.baseScaleFactor)))
        let cancellationPenalty = min(
            snapshot.cancelledSessions * AdherenceRisk.cancellationPenaltyPerSession,
            AdherenceRisk.cancellationPenaltyCap
        )
        let debtPenalty = snapshot.hasDebt ? AdherenceRisk.debtPenalty : 0

        return clamp(
            baseRisk + cancellationPenalty + debtPenalty,
            lower: 0,
            upper: 100
        )
    }

    private static func computeDropoutRisk(snapshot: PatientClinicalSnapshot) -> Int {
        let inactivityRisk: Int = {
            guard let days = snapshot.daysSinceLastSession else {
                return snapshot.nextSessionDate == nil
                    ? DropoutRisk.noHistoryNoUpcoming
                    : DropoutRisk.noHistoryWithUpcoming
            }

            switch days {
            case ..<7:
                return DropoutRisk.inactivityUnder7Days
            case 7..<14:
                return DropoutRisk.inactivity7to14Days
            case 14..<30:
                return DropoutRisk.inactivity14to30Days
            case 30..<60:
                return DropoutRisk.inactivity30to60Days
            default:
                return DropoutRisk.inactivityOver60Days
            }
        }()

        let upcomingPenalty    = snapshot.nextSessionDate == nil ? DropoutRisk.noUpcomingPenalty : 0
        let lowEngagementPenalty = snapshot.sessionCount <= DropoutRisk.lowEngagementThreshold
            ? DropoutRisk.lowEngagementPenalty : 0
        let diagnosisPenalty   = snapshot.diagnosisSummary == nil ? DropoutRisk.noDiagnosisPenalty : 0
        let debtPenalty        = snapshot.hasDebt ? DropoutRisk.debtPenalty : 0

        return clamp(
            inactivityRisk + upcomingPenalty + lowEngagementPenalty + diagnosisPenalty + debtPenalty,
            lower: 0,
            upper: 100
        )
    }

    private static func computeUrgency(
        totalScore: Int,
        adherenceRisk: Int,
        dropoutRisk: Int,
        snapshot: PatientClinicalSnapshot
    ) -> MentalHealthRiskUrgency {
        if totalScore >= UrgencyThreshold.immediateScore
            || (dropoutRisk >= UrgencyThreshold.immediateDropout && snapshot.nextSessionDate == nil) {
            return .immediate
        }

        if totalScore >= UrgencyThreshold.urgentScore || dropoutRisk >= UrgencyThreshold.urgentDropout {
            return .urgent
        }

        if totalScore >= UrgencyThreshold.soonScore || adherenceRisk >= UrgencyThreshold.soonAdherence {
            return .soon
        }

        return .routine
    }

    private static func clamp(
        _ value: Int,
        lower: Int,
        upper: Int
    ) -> Int {
        min(max(value, lower), upper)
    }
}
