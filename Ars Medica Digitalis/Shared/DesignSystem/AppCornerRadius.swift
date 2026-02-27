//
//  AppCornerRadius.swift
//  Ars Medica Digitalis
//
//  Radios de esquina estándar del design system. Centralizar estos valores
//  permite actualizar el lenguaje visual completo de la app en un solo lugar.
//

import CoreFoundation

enum AppCornerRadius {
    static let sm:   CGFloat = 12   // badges, pills pequeñas
    static let md:   CGFloat = 16   // cards secundarias (flat)
    static let lg:   CGFloat = 20   // cards primarias (elevated)
    static let pill: CGFloat = 100  // alias semántico para Capsule sintético
}
