//
//  SessionEditView.swift
//  Ars Medica Digitalis
//
//  Entrada semántica del editor de sesiones.
//  La lógica de IA para resumen clínico vive en SessionFormView y se reutiliza acá.
//

import SwiftUI

struct SessionEditView: View {

    let patient: Patient
    let session: Session?
    let initialDate: Date?

    init(patient: Patient, session: Session? = nil, initialDate: Date? = nil) {
        self.patient = patient
        self.session = session
        self.initialDate = initialDate
    }

    var body: some View {
        // Se delega a SessionFormView para mantener una sola implementación
        // del flujo completo (incluyendo resumen generado por Apple Intelligence).
        SessionFormView(
            patient: patient,
            session: session,
            initialDate: initialDate
        )
    }
}
