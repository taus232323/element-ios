//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import Arcana
import Combine
import Foundation
import MatrixRustSDKMocks
import Testing
import UIKit

@MainActor
final class LoginScreenViewModelTests {
    var viewModel: LoginScreenViewModelProtocol!
    var context: LoginScreenViewModelType.Context {
        viewModel.context
    }

    var service: LoginScreenAuthenticationServiceStub!

    @Test
    func basicServer() async {
        await setupViewModel()

        #expect(context.viewState.homeserver == .mockBasicServer)
        #expect(context.viewState.loginMode == .password)
        #expect(context.email.isEmpty)
        #expect(context.password.isEmpty)
        #expect(context.viewState.step == .credentials)
    }

    @Test
    func validCredentials() async {
        await setupViewModel()

        context.email = "alice@example.com"
        context.password = "12345678"

        #expect(context.viewState.hasValidCredentials)
        #expect(context.viewState.canSubmit)
    }

    @Test
    func missingEmailOrPassword() async {
        await setupViewModel()

        context.email = ""
        context.password = "12345678"
        #expect(!context.viewState.hasValidCredentials)
        #expect(!context.viewState.canSubmit)

        context.email = "alice@example.com"
        context.password = ""
        #expect(!context.viewState.hasValidCredentials)
        #expect(!context.viewState.canSubmit)
    }

    @Test
    func loginHint() async {
        await setupViewModel(loginHint: "")
        #expect(context.email == "")

        await setupViewModel(loginHint: "alice@example.com")
        #expect(context.email == "alice@example.com")
    }

    @Test
    func login() async throws {
        await setupViewModel()
        context.email = "alice@example.com"
        context.password = "12345678"

        let reachedCodeStep = deferFulfillment(context.observe(\.viewState.step)) { $0 == .verificationCode }
        context.send(viewAction: .next)
        try await reachedCodeStep.fulfill()

        let deferred = deferFulfillment(viewModel.actions) {
            if case .signedIn = $0 { true } else { false }
        }
        context.verificationCode = "123456"
        context.send(viewAction: .next)
        try await deferred.fulfill()
    }

    @Test
    func goBackFromVerificationCode() async throws {
        await setupViewModel()
        context.email = "alice@example.com"
        context.password = "12345678"
        let reachedCodeStep = deferFulfillment(context.observe(\.viewState.step)) { $0 == .verificationCode }
        context.send(viewAction: .next)
        try await reachedCodeStep.fulfill()

        let returnedToCredentials = deferFulfillment(context.observe(\.viewState.step)) { $0 == .credentials }
        context.send(viewAction: .back)
        try await returnedToCredentials.fulfill()
    }

    // MARK: - Helpers

    private func setupViewModel(homeserverAddress: String = "example.com", loginHint: String? = nil) async {
        service = LoginScreenAuthenticationServiceStub()
        guard case .success = await service.configure(for: homeserverAddress, flow: .login) else {
            Issue.record("A valid server should be configured for the test.")
            return
        }

        viewModel = LoginScreenViewModel(authenticationService: service,
                                         loginHint: loginHint,
                                         userIndicatorController: UserIndicatorControllerMock())
    }
}

@MainActor
final class LoginScreenAuthenticationServiceStub: AuthenticationServiceProtocol {
    let homeserverSubject = CurrentValueSubject<LoginHomeserver, Never>(.init(address: "example.com", loginMode: .password))
    var homeserver: CurrentValuePublisher<LoginHomeserver, Never> {
        homeserverSubject.asCurrentValuePublisher()
    }

    var flow: AuthenticationFlow = .login
    var classicAppAccount: ClassicAppAccount?

    private let successSession = UserSessionMock(.init())

    func configure(for homeserverAddress: String, flow: AuthenticationFlow) async -> Result<Void, AuthenticationServiceError> {
        self.flow = flow
        homeserverSubject.send(LoginHomeserver(address: homeserverAddress, loginMode: .password))
        return .success(())
    }

    func urlForOIDCLogin(loginHint: String?) async -> Result<OIDCAuthorizationDataProxy, AuthenticationServiceError> {
        .failure(.oidcError(.notSupported))
    }

    func abortOIDCLogin(data: OIDCAuthorizationDataProxy) async { }

    func loginWithOIDCCallback(_ callbackURL: URL) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        .failure(.failedLoggingIn)
    }

    func login(username: String, password: String, initialDeviceName: String?, deviceID: String?) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        .failure(.failedLoggingIn)
    }

    func startNativeLogin(login: String, password: String) async -> Result<PendingNativeLogin, AuthenticationServiceError> {
        .success(.init(homeserverUrl: "https://matrix.example.com",
                       login: login,
                       password: password,
                       clientSecret: "secret",
                       sendAttempt: 1,
                       sid: "sid",
                       email: login))
    }

    func continueNativeLogin(_ pendingLogin: PendingNativeLogin, verificationCode: String, initialDeviceName: String?, deviceID: String?) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        .success(successSession)
    }

    func resendNativeLoginCode(_ pendingLogin: PendingNativeLogin) async -> Result<PendingNativeLogin, AuthenticationServiceError> {
        .success(pendingLogin)
    }

    func startNativeRegistration(email: String) async -> Result<PendingNativeRegistration, AuthenticationServiceError> {
        .failure(.failedLoggingIn)
    }

    func continueNativeRegistrationEmailCode(_ pendingRegistration: PendingNativeRegistration, verificationCode: String) async -> Result<PendingNativeRegistration, AuthenticationServiceError> {
        .failure(.failedLoggingIn)
    }

    func finishNativeRegistration(_ pendingRegistration: PendingNativeRegistration, username: String?, password: String, initialDeviceName: String?, deviceID: String?) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        .failure(.failedLoggingIn)
    }

    func resendNativeRegistrationEmail(_ pendingRegistration: PendingNativeRegistration) async -> Result<PendingNativeRegistration, AuthenticationServiceError> {
        .failure(.failedLoggingIn)
    }

    func loginWithQRCode(data: Data) -> QRLoginProgressPublisher {
        CurrentValueSubject<QRLoginProgress, AuthenticationServiceError>(.starting).asCurrentValuePublisher()
    }

    func reset() {
        homeserverSubject.send(.init(address: "example.com", loginMode: .unknown))
        flow = .login
    }

    func setupClassicAppAccountState() async { }

    func refreshClassicAppAccountState() async { }
}
