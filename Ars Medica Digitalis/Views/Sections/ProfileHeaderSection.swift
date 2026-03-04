//
//  ProfileHeaderSection.swift
//  Ars Medica Digitalis
//
//  Seccion principal de identidad profesional.
//

import SwiftUI

struct ProfileHeaderSection: View {

    let fullName: String
    let professionalTitle: String
    let initials: String?
    let onEdit: () -> Void

    var body: some View {
        ProfileHeaderCard(
            initials: initials,
            fullName: fullName.isEmpty ? "Completa tu nombre profesional" : fullName,
            professionalTitle: professionalTitle.isEmpty ? "Agrega tu titulo profesional" : professionalTitle,
            onEdit: onEdit
        )
    }
}
