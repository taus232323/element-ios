//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDKMocks
import Testing

@MainActor
struct LoginScreenViewModelTests {
    var viewModel: LoginScreenViewModelProtocol!
    var context: LoginScreenViewModelType.Context {
        viewModel.context
    }
    
    var clientFactory: AuthenticationClientFactoryMock!
    var service: AuthenticationServiceProtocol!
    
    @Test
    mutating func basicServer() async {
        await setupViewModel()
        
        #expect(context.viewState.homeserver == .mockBasicServer)
        #expect(context.viewState.loginMode == .password)
        #expect(context.email.isEmpty)
        #expect(context.password.isEmpty)
    }
    
    @Test
    mutating func validCredentials() async {
        await setupViewModel()
        
        context.email = "alice@example.com"
        context.password = "12345678"
        
        #expect(context.viewState.hasValidCredentials)
        #expect(context.viewState.canSubmit)
    }
    
    @Test
    mutating func missingEmailOrPassword() async {
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
    mutating func loginHint() async {
        await setupViewModel(loginHint: "")
        #expect(context.email == "")

        await setupViewModel(loginHint: "alice@example.com")
        #expect(context.email == "alice@example.com")
    }
    
    @Test
    mutating func login() async throws {
        await setupViewModel()
        context.email = "alice@example.com"
        context.password = "12345678"
        
        let deferred = deferFulfillment(viewModel.actions) {
            if case .signedIn = $0 { true } else { false }
        }
        context.send(viewAction: .next)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksReceivedArguments?.homeserverAddress == "example.com")
    }
    
    // MARK: - Helpers
    
    private mutating func setupViewModel(homeserverAddress: String = "example.com", loginHint: String? = nil) async {
        var configuration = AuthenticationClientFactoryMock.Configuration()
        configuration.homeserverClients["example.com"] = ClientSDKMock(configuration: .init(serverAddress: "example.com",
                                                                                            homeserverURL: "https://matrix.example.com",
                                                                                            slidingSyncVersion: .native,
                                                                                            oidcLoginURL: nil,
                                                                                            supportsOIDCCreatePrompt: false,
                                                                                            supportsPasswordLogin: true,
                                                                                            validCredentials: (username: "alice@example.com", password: "12345678")))

        clientFactory = AuthenticationClientFactoryMock(configuration: configuration)
        service = AuthenticationService(userSessionStore: UserSessionStoreMock(configuration: .init()),
                                        encryptionKeyProvider: EncryptionKeyProvider(),
                                        classicAppManager: nil,
                                        clientFactory: clientFactory,
                                        appSettings: ServiceLocator.shared.settings,
                                        appHooks: AppHooks())
        
        guard case .success = await service
            .configure(for: homeserverAddress, flow: .login) else {
            Issue.record("A valid server should be configured for the test.")
            return
        }
        
        viewModel = LoginScreenViewModel(authenticationService: service,
                                         loginHint: loginHint,
                                         userIndicatorController: UserIndicatorControllerMock(),
                                         appSettings: ServiceLocator.shared.settings)
    }
}
