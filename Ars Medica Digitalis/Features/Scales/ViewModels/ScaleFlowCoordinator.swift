//
//  ScaleFlowCoordinator.swift
//  Ars Medica Digitalis
//
//  Coordinador de flujo de evaluación clínica.
//
//  Problema que resuelve:
//  Antes de este tipo, la señal "el usuario guardó el resultado" viajaba
//  hacia arriba como un callback (`onSessionSaved`) pasado por parámetro a
//  través de 4 niveles de vistas: ResultView → QuestionView → IntroView → ListView.
//  Ese prop-drilling era frágil, impedía añadir nuevas escalas sin tocar
//  los intermedios, y generaba un bug en el flujo MMSE (nunca se cerraba
//  el fullScreenCover porque la cadena se cortaba).
//
//  Solución:
//  ScaleFlowCoordinator vive en `ScalesListView` como `@State` y se inyecta
//  en el environment del fullScreenCover. Las vistas terminales del flujo
//  (ScaleResultView, MMSEAssessmentView) llaman `coordinator?.complete()`.
//  ScalesListView observa `isDone` y descarta el cover.
//
//  El acceso vía EnvironmentKey con defaultValue nil garantiza que:
//  - Las vistas no crashean si el coordinador no está inyectado (previews, tests).
//  - `complete()` es un no-op fuera del flujo real.
//

import SwiftUI

// MARK: - Coordinador

@Observable
final class ScaleFlowCoordinator {

    /// Señal de completado. ScalesListView la observa para descartar el cover.
    var isDone: Bool = false

    /// Las vistas terminales del flujo lo llaman al guardar el resultado.
    func complete() {
        isDone = true
    }

    /// ScalesListView lo llama en onDismiss del cover para preparar el siguiente flujo.
    func reset() {
        isDone = false
    }
}

// MARK: - EnvironmentKey

private struct ScaleFlowCoordinatorKey: EnvironmentKey {
    /// nil por defecto: las vistas llaman coordinator?.complete() sin riesgo de crash.
    static let defaultValue: ScaleFlowCoordinator? = nil
}

extension EnvironmentValues {
    /// Acceso al coordinador del flujo de escalas desde cualquier vista del árbol.
    var scaleFlowCoordinator: ScaleFlowCoordinator? {
        get { self[ScaleFlowCoordinatorKey.self] }
        set { self[ScaleFlowCoordinatorKey.self] = newValue }
    }
}
