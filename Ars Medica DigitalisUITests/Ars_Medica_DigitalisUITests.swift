//
//  Ars_Medica_DigitalisUITests.swift
//  Ars Medica DigitalisUITests
//
//  Created by Juan Ignacio Antolini on 18/02/2026.
//

import XCTest

final class Ars_Medica_DigitalisUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLaunchShowsPrimaryEntryPoint() throws {
        let app = XCUIApplication()
        app.launch()

        // Puede iniciar en onboarding o en tabs principales según datos persistidos.
        let onboardingTitle = app.navigationBars["Bienvenido"]
        let createProfileButton = app.buttons["Crear Perfil"]
        let patientsTab = app.tabBars.buttons["Pacientes"]
        let calendarTab = app.tabBars.buttons["Calendario"]

        let appears = onboardingTitle.waitForExistence(timeout: 4)
            || createProfileButton.waitForExistence(timeout: 1)
            || patientsTab.waitForExistence(timeout: 1)
            || calendarTab.waitForExistence(timeout: 1)

        XCTAssertTrue(
            appears,
            "La app debería mostrar onboarding o tabs principales tras el launch."
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
