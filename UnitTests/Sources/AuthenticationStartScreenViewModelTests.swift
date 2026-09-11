//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import Arcana
import MatrixRustSDKMocks
import Testing

@MainActor
final class AuthenticationStartScreenViewModelTests {
    var clientFactory: AuthenticationClientFactoryMock!
    var appSettings: AppSettings!
    var authenticationService: AuthenticationServiceProtocol!
    
    var viewModel: AuthenticationStartScreenViewModel!
    var context: AuthenticationStartScreenViewModel.Context {
        viewModel.context
    }
    
    init() {
        AppSettings.resetAllSettings()
        appSettings = AppSettings()
        // These app settings are kept local to the tests on purpose as if they are registered in the
        // ServiceLocator, the providers override that we apply will break other tests in the suite.
    }
    
    deinit {
        AppSettings.resetAllSettings()
    }
    
    @Test
    func initialState() async throws {
        // Given a view model that has no provisioning parameters.
        await setupViewModel()
        #expect(context.viewState.showCreateAccountButton)
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        
        // When tapping report the action should pass through without configuring a homeserver.
        let deferred = deferFulfillment(viewModel.actions) { $0 == .reportProblem }
        context.send(viewAction: .reportProblem)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 0)
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
    }
    
    @Test
    func registerConfiguresHomeserver() async throws {
        await setupViewModel()
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .register }
        context.send(viewAction: .register)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(authenticationService.homeserver.value.loginMode == .password)
    }
    
    @Test
    func loginConfiguresHomeserver() async throws {
        await setupViewModel()
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        
        let deferred = deferFulfillment(viewModel.actions) { $0.isLoginDirectlyWithPassword }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(authenticationService.homeserver.value.loginMode == .password)
    }
    
    @Test
    func provisionedPasswordState() async throws {
        // Given a view model that has been provisioned.
        await setupViewModel(provisioningParameters: .init(accountProvider: "company.com", loginHint: "user@company.com"))
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        
        // When tapping the login button the flow should continue directly with the login hint.
        let deferred = deferFulfillment(viewModel.actions) { $0.isLoginDirectlyWithPassword }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(authenticationService.homeserver.value.loginMode == .password)
    }
    
    // MARK: - Helpers
    
    private func setupViewModel(provisioningParameters: AccountProvisioningParameters? = nil) async {
        clientFactory = AuthenticationClientFactoryMock(configuration: .init())
        authenticationService = AuthenticationService(userSessionStore: UserSessionStoreMock(configuration: .init()),
                                                      encryptionKeyProvider: EncryptionKeyProvider(),
                                                      clientFactory: clientFactory,
                                                      appSettings: appSettings,
                                                      appHooks: AppHooks())
        
        viewModel = AuthenticationStartScreenViewModel(authenticationService: authenticationService,
                                                       provisioningParameters: provisioningParameters,
                                                       isBugReportServiceEnabled: true,
                                                       appSettings: appSettings,
                                                       mediaProvider: MediaProviderMock(configuration: .init()),
                                                       userIndicatorController: UserIndicatorControllerMock())
    }
}

extension AuthenticationStartScreenViewModelAction {
    var isLoginDirectlyWithPassword: Bool {
        switch self {
        case .loginDirectlyWithPassword: true
        default: false
        }
    }
}
