//
//  AppSpacing.swift
//  Ars Medica Digitalis
//
//  Constantes de espaciado centralizadas para evitar números mágicos dispersos
//  en el resto de las vistas y facilitar ajustes globales de layout.
//

import CoreFoundation

enum AppSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48

    // Contextos semánticos — evitan que las vistas conozcan valores absolutos
    static let cardPadding:    CGFloat = md
    static let rowInset:       CGFloat = xs
    static let sectionGap:     CGFloat = lg
    static let listRowPadding: CGFloat = sm
}
