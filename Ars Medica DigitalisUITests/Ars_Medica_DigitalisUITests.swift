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
    func testOnboardingAllowsTypingInProfessionalFields() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_ONBOARDING"]
        app.launch()

        let fullNameField = app.textFields["onboarding.fullName"]
        let specialtyField = app.textFields["onboarding.specialty"]
        let licenseField = app.textFields["onboarding.licenseNumber"]
        let emailField = app.textFields["onboarding.email"]

        XCTAssertTrue(fullNameField.waitForExistence(timeout: 6))
        XCTAssertTrue(specialtyField.exists)
        XCTAssertTrue(licenseField.exists)
        XCTAssertTrue(emailField.exists)

        type("Dra Ana Perez", in: fullNameField)
        type("Psicologia Clinica", in: specialtyField)
        type("MN12345", in: licenseField)
        type("ana@example.com", in: emailField)

        XCTAssertTrue(value(of: fullNameField).contains("Dra Ana Perez"))
        XCTAssertTrue(value(of: specialtyField).contains("Psicologia Clinica"))
        XCTAssertTrue(value(of: licenseField).contains("MN12345"))
        XCTAssertTrue(value(of: emailField).contains("ana@example.com"))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testProfileCanOpenClinicalDashboardWithoutFreezing() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_PROFILE_DASHBOARD"]
        app.launch()

        openClinicalDashboard(from: app)

        let dashboardTitle = app.navigationBars["Dashboard Clínico"]
        XCTAssertTrue(
            dashboardTitle.waitForExistence(timeout: 6),
            "La navegación debe abrir la vista de charts (Dashboard) sin colgar la app."
        )
    }

    @MainActor
    func testProfileClinicalDashboardCanNavigateBackToProfile() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_PROFILE_DASHBOARD"]
        app.launch()

        openClinicalDashboard(from: app)

        let dashboardTitle = app.navigationBars["Dashboard Clínico"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 6))

        let backButton = dashboardTitle.buttons["Perfil"]
        if backButton.exists {
            backButton.tap()
        } else {
            XCTAssertTrue(dashboardTitle.buttons.firstMatch.waitForExistence(timeout: 2))
            dashboardTitle.buttons.firstMatch.tap()
        }

        let profileTitle = app.navigationBars["Perfil"]
        XCTAssertTrue(
            profileTitle.waitForExistence(timeout: 6),
            "Luego de abrir Dashboard (charts), volver atrás debe seguir respondiendo."
        )
    }

    @MainActor
    func testScalesFlowCanOpenScaleIntroWithoutFreezing() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_SCALES"]
        app.launch()

        openPatientDetail(from: app)

        let scalesEntry = firstExistingElement(
            for: "patient.detail.scales",
            in: app
        )
        XCTAssertTrue(scalesEntry.waitForExistence(timeout: 6))
        scalesEntry.tap()

        let scaleRow = firstExistingElement(
            for: "scale.row.BDI-II",
            in: app
        )
        XCTAssertTrue(
            scaleRow.waitForExistence(timeout: 6),
            "La escala BDI-II debería poder abrirse desde la lista."
        )
        scaleRow.tap()

        let beginButton = app.buttons["scale.intro.begin"]
        XCTAssertTrue(
            beginButton.waitForExistence(timeout: 6),
            "Al tocar la escala, la intro debe mostrarse sin congelar la app."
        )
    }

    private func type(_ text: String, in textField: XCUIElement) {
        textField.tap()
        textField.typeText(text)
    }

    private func value(of textField: XCUIElement) -> String {
        textField.value as? String ?? ""
    }

    private func openClinicalDashboard(from app: XCUIApplication) {
        openPatientList(from: app)

        let profileButton = app.buttons["main.profile"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()

        let profileTitle = app.navigationBars["Perfil"]
        XCTAssertTrue(profileTitle.waitForExistence(timeout: 5))

        let clinicalDashboardEntry = firstExistingElement(
            for: "profile.stats.clinicalDashboard",
            in: app
        )
        XCTAssertTrue(clinicalDashboardEntry.waitForExistence(timeout: 5))
        clinicalDashboardEntry.tap()
    }

    private func openPatientDetail(from app: XCUIApplication) {
        openPatientList(from: app)

        let patientCard = firstExistingElement(
            for: "patient.card.Paciente Demo",
            in: app
        )
        XCTAssertTrue(patientCard.waitForExistence(timeout: 6))
        patientCard.tap()
    }

    private func openPatientList(from app: XCUIApplication) {
        let patientsTab = app.tabBars.buttons["Pacientes"]
        XCTAssertTrue(patientsTab.waitForExistence(timeout: 5))
        patientsTab.tap()
    }

    private func firstExistingElement(for identifier: String, in app: XCUIApplication) -> XCUIElement {
        let linksMatch = app.links[identifier]
        if linksMatch.exists {
            return linksMatch
        }

        let buttonMatch = app.buttons[identifier]
        if buttonMatch.exists {
            return buttonMatch
        }

        let staticTextMatch = app.staticTexts[identifier]
        if staticTextMatch.exists {
            return staticTextMatch
        }

        return app.otherElements[identifier]
    }
}
