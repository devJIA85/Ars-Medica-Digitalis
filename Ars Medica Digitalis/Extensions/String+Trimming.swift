//
//  String+Trimming.swift
//  Ars Medica Digitalis
//
//  Helpers compartidos para normalizar texto de formularios.
//

import Foundation

public extension String {
    /// Atajo para .trimmingCharacters(in: .whitespaces)
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
