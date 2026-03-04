//
//  ClinicalPriorityRadarBuilder.swift
//  Ars Medica Digitalis
//
//  Builder puro del radar clínico a partir del estado del dashboard.
//

import Foundation

enum ClinicalPriorityRadarBuilder {

    static func build(from state: PatientDashboardState) -> ClinicalPriorityRadarModel {
        ClinicalPriorityRadarModel(
            totalCount: state.summary.totalPatients,
            criticalCount: state.summary.criticalPatientsCount,
            attentionCount: state.summary.attentionPatientsCount,
            stableCount: state.summary.stablePatientsCount
        )
    }
}

