//
//  MiniClinicalRadarView.swift
//  Ars Medica Digitalis
//
//  Versión compacta del radar clínico para encabezados colapsados.
//

import SwiftUI

struct MiniClinicalRadarView: View {

    let model: ClinicalPriorityRadarModel
    let selectedBucket: ClinicalPriorityBucket?
    let onSelectBucket: (ClinicalPriorityBucket?) -> Void

    var body: some View {
        ClinicalPriorityRadar(
            model: model,
            size: .mini,
            selectedBucket: selectedBucket,
            onSelectBucket: onSelectBucket
        )
        .accessibilitySortPriority(2)
    }
}

