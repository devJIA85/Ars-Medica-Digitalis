//
//  RingArcShape.swift
//  Ars Medica Digitalis
//
//  Primitive de arco para el radar clínico.
//

import SwiftUI

struct RingArcShape: Shape {

    var startAngle: Angle
    var endAngle: Angle
    var lineWidth: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(startAngle.degrees, endAngle.degrees)
        }
        set {
            // WHAT: Exponemos inicio/fin del arco como datos animables.
            // WHY: SwiftUI interpola estos valores y evita recalcular
            // paths complejos por frame fuera del pipeline de Shape.
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rawRadius = (min(rect.width, rect.height) * 0.5) - (lineWidth * 0.5)
        let radius = max(rawRadius, 0)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
