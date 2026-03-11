//
//  ClinicalScoreRing.swift
//  Ars Medica Digitalis
//
//  Anillo de score clínico con segmentos por rango de severidad.
//  Cada rango se renderiza como un arco coloreado; el score actual
//  marca el progreso dentro del segmento activo.
//

import SwiftUI

// MARK: - Full ring

struct ClinicalScoreRing: View {

    let score: Int
    let maxScore: Int
    let ranges: [ScoreRange]
    let colorName: String
    let severity: String

    init(
        score: Int,
        maxScore: Int,
        ranges: [ScoreRange] = [],
        colorName: String,
        severity: String
    ) {
        self.score = score
        self.maxScore = maxScore
        self.ranges = ranges
        self.colorName = colorName
        self.severity = severity
    }

    private var scoreRatio: Double {
        guard maxScore > 0 else { return 0 }
        return min(Double(score) / Double(maxScore), 1.0)
    }

    private var activeColor: Color {
        Color.clinicalRingColor(named: colorName, severity: severity)
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(.gray.opacity(0.15), lineWidth: 14)

            if ranges.count >= 2 {
                segmentedArcs
            } else {
                singleArc
            }

            // Score text
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.primary)

                Text("/ \(maxScore)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 140, height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) de \(maxScore)")
    }

    // Fallback: single colored arc when no ranges provided
    private var singleArc: some View {
        Circle()
            .trim(from: 0, to: scoreRatio)
            .stroke(
                activeColor,
                style: StrokeStyle(lineWidth: 14, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.8), value: score)
    }

    // Segmented arcs: one arc per range, filled up to score
    private var segmentedArcs: some View {
        ForEach(Array(ranges.enumerated()), id: \.offset) { _, range in
            let segment = arcSegment(for: range)
            if segment.trimTo > segment.trimFrom {
                Circle()
                    .trim(from: segment.trimFrom, to: segment.trimTo)
                    .stroke(
                        Color.clinicalRingColor(named: range.color, severity: range.severity),
                        style: StrokeStyle(lineWidth: 14, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: score)
            }
        }
    }

    private func arcSegment(for range: ScoreRange) -> (trimFrom: Double, trimTo: Double) {
        guard maxScore > 0 else { return (0, 0) }

        let rangeStart = Double(max(range.min, 0)) / Double(maxScore)
        let rangeEnd = Double(min(range.max, maxScore)) / Double(maxScore)

        // Only draw up to the current score
        let effectiveEnd = min(rangeEnd, scoreRatio)

        guard effectiveEnd > rangeStart else { return (0, 0) }
        return (rangeStart, effectiveEnd)
    }
}

// MARK: - Mini variant

struct ClinicalScoreRingMini: View {

    let score: Int
    let maxScore: Int
    let colorName: String
    let severity: String

    private var scoreRatio: Double {
        guard maxScore > 0 else { return 0 }
        return min(Double(score) / Double(maxScore), 1.0)
    }

    private var ringColor: Color {
        Color.clinicalRingColor(named: colorName, severity: severity)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.gray.opacity(0.15), lineWidth: 4)

            Circle()
                .trim(from: 0, to: scoreRatio)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 40, height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) de \(maxScore)")
    }
}

// MARK: - Shared color mapping

extension Color {
    static func clinicalRingColor(named colorName: String, severity: String) -> Color {
        switch colorName.lowercased() {
        case "green": .green
        case "yellow": .yellow
        case "orange": .orange
        case "red": .red
        case "blue": .blue
        case "purple": .purple
        case "teal": .teal
        default:
            switch severity.lowercased() {
            case "normal": .green
            case "mildmooddisturbance": .yellow
            case "intermittentdepression", "moderatedepression": .orange
            case "severedepression": .red
            case "extremedepression": .purple
            // Legacy fallbacks
            case "minimal": .green
            case "mild": .yellow
            case "moderate": .orange
            case "severe": .red
            default: .secondary
            }
        }
    }
}

// MARK: - Previews

#Preview("Segmented Ring — Severe") {
    ClinicalScoreRing(
        score: 35,
        maxScore: 63,
        ranges: [
            ScoreRange(min: 0, max: 10, label: "Normal", severity: "normal", color: "green"),
            ScoreRange(min: 11, max: 16, label: "Leve", severity: "mildMoodDisturbance", color: "yellow"),
            ScoreRange(min: 17, max: 20, label: "Intermitente", severity: "intermittentDepression", color: "orange"),
            ScoreRange(min: 21, max: 30, label: "Moderada", severity: "moderateDepression", color: "orange"),
            ScoreRange(min: 31, max: 40, label: "Grave", severity: "severeDepression", color: "red"),
            ScoreRange(min: 41, max: 63, label: "Extrema", severity: "extremeDepression", color: "purple"),
        ],
        colorName: "red",
        severity: "severeDepression"
    )
    .padding()
}

#Preview("Segmented Ring — Normal") {
    ClinicalScoreRing(
        score: 7,
        maxScore: 63,
        ranges: [
            ScoreRange(min: 0, max: 10, label: "Normal", severity: "normal", color: "green"),
            ScoreRange(min: 11, max: 16, label: "Leve", severity: "mildMoodDisturbance", color: "yellow"),
            ScoreRange(min: 17, max: 20, label: "Intermitente", severity: "intermittentDepression", color: "orange"),
            ScoreRange(min: 21, max: 30, label: "Moderada", severity: "moderateDepression", color: "orange"),
            ScoreRange(min: 31, max: 40, label: "Grave", severity: "severeDepression", color: "red"),
            ScoreRange(min: 41, max: 63, label: "Extrema", severity: "extremeDepression", color: "purple"),
        ],
        colorName: "green",
        severity: "normal"
    )
    .padding()
}

#Preview("Single Color Ring") {
    ClinicalScoreRing(score: 31, maxScore: 63, colorName: "red", severity: "severe")
        .padding()
}

#Preview("Mini Ring") {
    HStack(spacing: 12) {
        ClinicalScoreRingMini(score: 9, maxScore: 63, colorName: "green", severity: "normal")
        VStack(alignment: .leading) {
            Text("Altibajos normales")
                .font(.subheadline.weight(.semibold))
            Text("Score 9")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
