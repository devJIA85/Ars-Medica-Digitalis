//
//  ICD11Entry.swift
//  Ars Medica Digitalis
//
//  Catálogo offline del CIE-11 MMS en español.
//  Cada registro es una entrada de la linearización MMS descargada
//  previamente y persistida localmente para búsqueda sin conexión.
//
//  Separado de Diagnosis: este es el catálogo de referencia,
//  Diagnosis es el snapshot inmutable asociado a un paciente/sesión.
//
//  No tiene relaciones con otros modelos — es un catálogo independiente.
//

import Foundation
import SwiftData

@Model
final class ICD11Entry {

    var id: UUID = UUID()

    /// Código MMS (ej: "6A70", "1A00.1"). Indexado para búsquedas rápidas.
    var code: String = ""

    /// Título en español (ej: "Trastorno depresivo de episodio único")
    var title: String = ""

    /// URI canónico del WHO (ej: "http://id.who.int/icd/entity/578635574")
    var uri: String = ""

    /// Tipo de entidad en la jerarquía MMS
    /// "chapter" | "block" | "category" | "window"
    var classKind: String = ""

    /// Código del capítulo raíz al que pertenece (ej: "06" para Salud mental)
    /// Permite filtrar/agrupar por capítulo en futuras funcionalidades.
    var chapterCode: String = ""

    init(
        id: UUID = UUID(),
        code: String = "",
        title: String = "",
        uri: String = "",
        classKind: String = "",
        chapterCode: String = ""
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.uri = uri
        self.classKind = classKind
        self.chapterCode = chapterCode
    }
}
