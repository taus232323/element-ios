//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import XCTest

@MainActor
class AuthenticationFlowCoordinatorUITests: XCTestCase {
    func testLoginWithPassword() async throws {
        // Given the authentication flow.
        let app = Application.launch(.authenticationFlow)
        
        // Check the bug report flow works.
        try await verifyReportBugButton(app)
        
        // Splash Screen: Tap get started button
        app.buttons[A11yIdentifiers.authenticationStartScreen.signIn].tap()
        
        // Login Screen: Wait for continue button to appear
        let continueButton = app.buttons[A11yIdentifiers.loginScreen.continue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2.0))
        
        // Login Screen: Enter valid credentials
        app.textFields[A11yIdentifiers.loginScreen.emailUsername].clearAndTypeText("alice\n", app: app)
        app.secureTextFields[A11yIdentifiers.loginScreen.password].clearAndTypeText("12345678", app: app)

        try await app.assertScreenshot()
        
        // Login Screen: Tap next
        app.buttons[A11yIdentifiers.loginScreen.continue].tap()
    }
    
    func testLoginWithIncorrectPassword() {
        // Given the authentication flow.
        let app = Application.launch(.authenticationFlow)
        
        // Splash Screen: Tap get started button
        app.buttons[A11yIdentifiers.authenticationStartScreen.signIn].tap()
        
        // Login Screen: Wait for continue button to appear
        let continueButton = app.buttons[A11yIdentifiers.loginScreen.continue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2.0))
        
        // Login Screen: Enter invalid credentials
        app.textFields[A11yIdentifiers.loginScreen.emailUsername].clearAndTypeText("alice", app: app)
        app.secureTextFields[A11yIdentifiers.loginScreen.password].clearAndTypeText("87654321", app: app)

        // Login Screen: Tap continue
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()
        
        // Then login should fail.
        XCTAssertTrue(app.alerts.element.waitForExistence(timeout: 2.0), "An error alert should be shown when attempting login with invalid credentials.")
    }
    
    func testLoginWithMatrixIdLikeInput() {
        // Given the authentication flow.
        let app = Application.launch(.authenticationFlow)
        
        // Splash Screen: Tap get started button
        app.buttons[A11yIdentifiers.authenticationStartScreen.signIn].tap()
        
        // Login Screen: Wait for continue button to appear
        let continueButton = app.buttons[A11yIdentifiers.loginScreen.continue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2.0))
        
        // When entering a Matrix ID-like value on the login screen.
        app.textFields[A11yIdentifiers.loginScreen.emailUsername].clearAndTypeText("@test:server.net\n", app: app)
        app.secureTextFields[A11yIdentifiers.loginScreen.password].clearAndTypeText("12345678", app: app)
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()
        
        // Then login should fail with the normal invalid-credentials flow.
        XCTAssertTrue(app.alerts.element.waitForExistence(timeout: 2.0), "An error alert should be shown when attempting login with unsupported credentials.")
    }
    
    func testProvisionedLoginWithPassword() async throws {
        // Given a provisioned authentication flow.
        let app = Application.launch(.provisionedAuthenticationFlow)
        
        // Then the start screen should be configured appropriately.
        try await app.assertScreenshot()
        
        // Check the bug report flow works.
        try await verifyReportBugButton(app)
        
        // Splash Screen: Tap get started button
        app.buttons[A11yIdentifiers.authenticationStartScreen.signIn].tap()
        
        // No server selection should be shown here
        
        // Login Screen: Wait for continue button to appear
        let continueButton = app.buttons[A11yIdentifiers.loginScreen.continue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2.0))
        
        // Login Screen: Enter valid credentials
        app.textFields[A11yIdentifiers.loginScreen.emailUsername].clearAndTypeText("alice\n", app: app)
        app.secureTextFields[A11yIdentifiers.loginScreen.password].clearAndTypeText("12345678", app: app)
        
        // Login Screen: Tap next
        app.buttons[A11yIdentifiers.loginScreen.continue].tap()
    }
    
    func testSingleProviderLoginWithPassword() async throws {
        // Given the authentication flow with a single supported server.
        let app = Application.launch(.singleProviderAuthenticationFlow)
        
        // Then the start screen should be configured appropriately.
        try await app.assertScreenshot()
        
        // Check the bug report flow works.
        try await verifyReportBugButton(app)
        
        // Splash Screen: Tap get started button
        app.buttons[A11yIdentifiers.authenticationStartScreen.signIn].tap()
        
        // No server selection should be shown here
        
        // Login Screen: Wait for continue button to appear
        let continueButton = app.buttons[A11yIdentifiers.loginScreen.continue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2.0))
        
        // Login Screen: Enter valid credentials
        app.textFields[A11yIdentifiers.loginScreen.emailUsername].clearAndTypeText("alice\n", app: app)
        app.secureTextFields[A11yIdentifiers.loginScreen.password].clearAndTypeText("12345678", app: app)
        
        // Login Screen: Tap next
        app.buttons[A11yIdentifiers.loginScreen.continue].tap()
    }
    
    func testMultipleProvidersLoginWithPassword() async throws {
        // Given the authentication flow with only 2 allowed servers.
        let app = Application.launch(.multipleProvidersAuthenticationFlow)
        
        // Then the start screen should be configured appropriately.
        try await app.assertScreenshot()
        
        // Splash Screen: Tap get started button
        app.buttons[A11yIdentifiers.authenticationStartScreen.signIn].tap()
        
        // Login Screen: Wait for continue button to appear
        let continueButton = app.buttons[A11yIdentifiers.loginScreen.continue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2.0))
        
        // Login Screen: Enter valid credentials
        app.textFields[A11yIdentifiers.loginScreen.emailUsername].clearAndTypeText("alice\n", app: app)
        app.secureTextFields[A11yIdentifiers.loginScreen.password].clearAndTypeText("12345678", app: app)
        
        // Login Screen: Tap next
        app.buttons[A11yIdentifiers.loginScreen.continue].tap()
    }
    
    func verifyReportBugButton(_ app: XCUIApplication) async throws {
        // Splash Screen: Open the report problem flow.
        app.buttons[A11yIdentifiers.authenticationStartScreen.reportProblem].tap()

        // Bug report: Make sure it exists then cancel.
        XCTAssert(app.textFields[A11yIdentifiers.bugReportScreen.report].exists)
        app.buttons[A11yIdentifiers.bugReportScreen.cancel].tap()
    }
}
