//
//  PatientCreationState.swift
//  Ars Medica Digitalis
//
//  Estado de flujo para alta/edición de pacientes.
//

import SwiftUI

@Observable
final class PatientCreationState {

    enum PresentationMode: String, CaseIterable, Identifiable {
        case singlePage
        case stepByStep

        var id: String { rawValue }

        var title: String {
            switch self {
            case .singlePage:
                "Vista continua"
            case .stepByStep:
                "Vista por pasos"
            }
        }

        var systemImage: String {
            switch self {
            case .singlePage:
                "rectangle.grid.1x2"
            case .stepByStep:
                "list.number"
            }
        }
    }

    enum Step: Int, CaseIterable, Identifiable {
        case personal
        case coverage
        case contact
        case finance

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .personal:
                "Datos personales"
            case .coverage:
                "Identificación y cobertura"
            case .contact:
                "Contacto"
            case .finance:
                "Finanzas"
            }
        }
    }

    var presentationMode: PresentationMode = .singlePage
    var currentStep: Step = .personal

    private var userDidOverridePresentationMode = false

    var isStepModeEnabled: Bool {
        presentationMode == .stepByStep
    }

    var canGoBack: Bool {
        currentStep.rawValue > 0
    }

    var canGoForward: Bool {
        currentStep.rawValue < Step.allCases.count - 1
    }

    var progressValue: Double {
        let total = Double(Step.allCases.count)
        let current = Double(currentStep.rawValue + 1)
        return current / total
    }

    var stepSummary: String {
        "Paso \(currentStep.rawValue + 1) de \(Step.allCases.count)"
    }

    func adaptPresentationModeIfNeeded(
        verticalSizeClass: UserInterfaceSizeClass?,
        dynamicTypeSize: DynamicTypeSize
    ) {
        guard userDidOverridePresentationMode == false else { return }

        let shouldUseStepMode = verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
        presentationMode = shouldUseStepMode ? .stepByStep : .singlePage

        if shouldUseStepMode == false {
            currentStep = .personal
        }
    }

    func setPresentationMode(_ mode: PresentationMode) {
        userDidOverridePresentationMode = true
        presentationMode = mode

        if mode == .singlePage {
            currentStep = .personal
        }
    }

    func goToNextStep() {
        guard canGoForward else { return }
        let nextIndex = currentStep.rawValue + 1
        if let step = Step(rawValue: nextIndex) {
            currentStep = step
        }
    }

    func goToPreviousStep() {
        guard canGoBack else { return }
        let previousIndex = currentStep.rawValue - 1
        if let step = Step(rawValue: previousIndex) {
            currentStep = step
        }
    }
}
