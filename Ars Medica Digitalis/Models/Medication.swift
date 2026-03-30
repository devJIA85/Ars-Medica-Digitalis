//
//  Medication.swift
//  Ars Medica Digitalis
//
//  Catálogo local de medicamentos (vademécum) para selección
//  en historia clínica y reutilización entre pacientes.
//

import Foundation
import SwiftData

@Model
final class Medication: Identifiable {

    var id: UUID = UUID()

    // MARK: - Campos del vademécum

    var principioActivo: String = ""
    var nombreComercial: String = ""
    var potencia: String = ""
    var potenciaValor: String = ""
    var potenciaUnidad: String = ""
    var contenido: String = ""
    var presentacion: String = ""
    var laboratorio: String = ""

    /// Permite distinguir catálogo semilla vs cargado manualmente por el profesional.
    var isUserCreated: Bool = false

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Relación inversa many-to-many con pacientes.
    /// La definición canónica vive en Patient.currentMedications.
    var patients: [Patient]! = []

    init(
        id: UUID = UUID(),
        principioActivo: String = "",
        nombreComercial: String = "",
        potencia: String = "",
        potenciaValor: String = "",
        potenciaUnidad: String = "",
        contenido: String = "",
        presentacion: String = "",
        laboratorio: String = "",
        isUserCreated: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        patients: [Patient] = []
    ) {
        self.id = id
        self.principioActivo = principioActivo
        self.nombreComercial = nombreComercial
        self.potencia = potencia
        self.potenciaValor = potenciaValor
        self.potenciaUnidad = potenciaUnidad
        self.contenido = contenido
        self.presentacion = presentacion
        self.laboratorio = laboratorio
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.patients = patients
    }
}

extension Medication {

    /// Título principal para listas.
    var primaryDisplayName: String {
        principioActivo.isEmpty ? "Sin principio activo" : principioActivo
    }

    /// Subtítulo para listas.
    var secondaryDisplayName: String {
        nombreComercial.isEmpty ? "Sin nombre comercial" : nombreComercial
    }

    /// Línea compacta para resumen de historia clínica/PDF.
    var summaryLabel: String {
        if !principioActivo.isEmpty && !nombreComercial.isEmpty {
            return "\(principioActivo) (\(nombreComercial))"
        }
        if !principioActivo.isEmpty { return principioActivo }
        if !nombreComercial.isEmpty { return nombreComercial }
        return "Medicamento sin especificar"
    }
}
