//
//  MetadataSection.swift
//  Ars Medica Digitalis
//
//  Trazabilidad de solo lectura del perfil profesional.
//

import SwiftUI

struct MetadataSection: View {

    let createdDate: String
    let lastModifiedDate: String

    var body: some View {
        SettingsSectionCard(
            title: "Metadata",
            systemImage: "clock.badge.checkmark",
            subtitle: "Fechas sincronizadas para auditoria y trazabilidad."
        ) {
            MetadataRow(
                title: "Creado",
                value: createdDate,
                systemImage: "calendar.badge.clock"
            )

            Divider()

            MetadataRow(
                title: "Ultima modificacion",
                value: lastModifiedDate,
                systemImage: "pencil.and.outline"
            )
        }
    }
}
