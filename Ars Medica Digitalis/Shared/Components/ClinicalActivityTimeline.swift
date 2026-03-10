//
//  ClinicalActivityTimeline.swift
//  Ars Medica Digitalis
//
//  Resumen temporal de la actividad clínica reciente del paciente.
//  Combina sesiones, diagnósticos y escalas en un timeline compacto
//  para que el profesional entienda de un vistazo qué ocurrió y cuándo.
//

import SwiftUI
import SwiftData

struct ClinicalActivityTimeline: View {

    let patient: Patient

    @Query private var scaleResults: [PatientScaleResult]

    private static let maxEvents = 5

    init(patient: Patient) {
        self.patient = patient
        let patientID = patient.id
        _scaleResults = Query(
            filter: #Predicate<PatientScaleResult> { $0.patientID == patientID },
            sort: [SortDescriptor(\PatientScaleResult.date, order: .reverse)]
        )
    }

    var body: some View {
        let events = buildEvents()
        if events.isEmpty == false {
            CardContainer(style: .flat) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Actividad clínica")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            timelineRow(
                                event: event,
                                isFirst: index == 0,
                                isLast: index == events.count - 1
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timelineRow(event: ClinicalEvent, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Timeline indicator
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 2, height: isFirst ? 0 : 8)
                    .opacity(isFirst ? 0 : 1)

                Circle()
                    .fill(event.tint.opacity(0.8))
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 2)
                    .frame(minHeight: isLast ? 0 : 16, maxHeight: .infinity)
                    .opacity(isLast ? 0 : 1)
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(event.date.esDayMonthAbbrev())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Spacer(minLength: 0)

            Image(systemName: event.systemImage)
                .font(.caption)
                .foregroundStyle(event.tint)
                .padding(.top, 6)
        }
    }

    // MARK: - Event builder

    private func buildEvents() -> [ClinicalEvent] {
        var events: [ClinicalEvent] = []

        // Sessions
        for session in patient.sessions ?? [] {
            let summary: String
            if session.sessionStatusValue == .completada {
                summary = "Sesión completada"
            } else if session.sessionStatusValue == .programada {
                summary = "Sesión programada"
            } else {
                summary = "Sesión cancelada"
            }
            events.append(ClinicalEvent(
                id: session.id,
                date: session.sessionDate,
                title: summary,
                systemImage: "stethoscope",
                tint: session.sessionStatusValue == .completada ? .green : .orange
            ))
        }

        // Diagnoses
        for diagnosis in patient.activeDiagnoses ?? [] {
            events.append(ClinicalEvent(
                id: diagnosis.id,
                date: diagnosis.diagnosedAt,
                title: "Dx: \(diagnosis.displayTitle)",
                systemImage: "cross.case",
                tint: .blue
            ))
        }

        // Scale results
        for result in scaleResults {
            events.append(ClinicalEvent(
                id: result.id,
                date: result.date,
                title: "\(result.scaleID.uppercased()) completado",
                systemImage: "list.bullet.clipboard",
                tint: .purple
            ))
        }

        events.sort { $0.date > $1.date }
        return Array(events.prefix(Self.maxEvents))
    }
}

// MARK: - Event model

private struct ClinicalEvent: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let systemImage: String
    let tint: Color
}
