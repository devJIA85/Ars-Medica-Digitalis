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
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let xxl: CGFloat = 24

    // Contextos semánticos — evitan que las vistas conozcan valores absolutos
    static let cardPadding:    CGFloat = 16
    static let rowInset:       CGFloat = 6
    static let sectionGap:     CGFloat = 20
    static let listRowPadding: CGFloat = 8
}
