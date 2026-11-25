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
    var clientFactory: ClientFactoryMock!
    var appSettings: AppSettings!
    var authenticationService: AuthenticationServiceProtocol!
    
    var viewModel: AuthenticationStartScreenViewModel!
    var context: AuthenticationStartScreenViewModel.Context {
        viewModel.context
    }
    
    init() {
        appSettings = AppSettings.volatile()
    }
    
    @Test
    func initialState() async throws {
        await setupViewModel()
        #expect(context.viewState.showCreateAccountButton)
        #expect(context.viewState.mode == .welcome)
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .reportProblem }
        context.send(viewAction: .reportProblem)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeAuthenticationClientServerNameOrBaseURLSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 0)
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
    }
    
    @Test
    func registerConfiguresHomeserver() async throws {
        await setupViewModel()
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .register }
        context.send(viewAction: .register)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeAuthenticationClientServerNameOrBaseURLSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(authenticationService.homeserver.value.loginMode == .password)
        #expect(authenticationService.flow == .register)
    }
    
    @Test
    func loginConfiguresHomeserver() async throws {
        await setupViewModel()
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        
        let deferred = deferFulfillment(viewModel.actions) { $0.isLoginDirectlyWithPassword }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeAuthenticationClientServerNameOrBaseURLSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(authenticationService.homeserver.value.loginMode == .password)
        #expect(authenticationService.flow == .login)
    }
    
    @Test
    func provisionedPasswordState() async throws {
        await setupViewModel(provisioningParameters: .init(accountProvider: "company.com", loginHint: "user@company.com"))
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .loginDirectlyWithPassword(loginHint: "user@company.com") }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeAuthenticationClientServerNameOrBaseURLSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(authenticationService.homeserver.value.loginMode == .password)
    }
    
    @Test
    func addAccount() async throws {
        await setupViewModel(isAddingAccount: true)
        #expect(context.viewState.mode == .addAccount)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .cancelAddingAccount }
        context.send(viewAction: .cancelAddingAccount)
        try await deferred.fulfill()
    }
    
    // MARK: - Helpers
    
    private func setupViewModel(provisioningParameters: AccountProvisioningParameters? = nil,
                                isAddingAccount: Bool = false) async {
        clientFactory = ClientFactoryMock(.init())
        clientFactory.makeAuthenticationClientServerNameOrBaseURLSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksClosure = { address, _, _, _, _, _ in
            ClientSDKMock(.init(serverName: address,
                                homeserverURL: "https://\(address)",
                                oAuthLoginURL: nil,
                                supportsPasswordLogin: true))
        }
        
        authenticationService = AuthenticationService(userSessionManager: UserSessionManagerMock(.init()),
                                                      encryptionKeyProvider: EncryptionKeyProvider(),
                                                      clientFactory: clientFactory,
                                                      appSettings: appSettings,
                                                      appHooks: AppHooks(),
                                                      targetContext: .mock)
        
        viewModel = AuthenticationStartScreenViewModel(authenticationService: authenticationService,
                                                       provisioningParameters: provisioningParameters,
                                                       isAddingAccount: isAddingAccount,
                                                       isBugReportServiceEnabled: true,
                                                       appSettings: appSettings,
                                                       mediaProvider: MediaProviderMock(.init()),
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
