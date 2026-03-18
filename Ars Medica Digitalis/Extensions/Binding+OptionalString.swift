//
//  Binding+OptionalString.swift
//  Ars Medica Digitalis
//
//  Elimina el boilerplate de convertir un String? en Binding<Bool>
//  para alertas y sheets controlados por mensajes de error opcionales.
//
//  Uso:
//    .alert("Error", isPresented: $saveErrorMessage.isPresent) { ... }
//

import SwiftUI

extension Binding where Value == String? {

    /// Devuelve un Binding<Bool> que es true cuando el String? no es nil.
    /// Al desactivarse (set false) limpia el String automáticamente.
    var isPresent: Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { if !$0 { wrappedValue = nil } }
        )
    }
}
