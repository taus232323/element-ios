//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import Arcana
import Foundation
import MatrixRustSDK
import MatrixRustSDKMocks
import Testing

@MainActor
struct AuthenticationServiceTests {
    var client: ClientSDKMock!
    var encryption: EncryptionSDKMock!
    var userSessionManager: UserSessionManagerMock!
    var encryptionKeyProvider: MockEncryptionKeyProvider!
    var appSettings: AppSettings!
    var targetContext: Target.Context!
    var service: AuthenticationService!
    
    @Test("A server without OAuth can be logged in to with a password")
    mutating func passwordLogin() async throws {
        try await setup(serverNameOrBaseURL: "example.com")
        
        switch await service.configure(for: "example.com", flow: .login) {
        case .success:
            break
        case .failure(let error):
            Issue.record("Unexpected failure: \(error)")
        }
        
        #expect(service.flow == .login)
        #expect(service.homeserver.value == .mockBasicServer)
        
        switch await service.login(username: "alice", password: "12345678", initialDeviceName: nil, deviceID: nil) {
        case .success:
            #expect(client.loginUsernamePasswordInitialDeviceNameDeviceIdCallsCount == 1)
            #expect(userSessionManager.userSessionForSessionDirectoriesPassphraseCallsCount == 1)
            #expect(userSessionManager.userSessionForSessionDirectoriesPassphraseReceivedArguments?.passphrase == encryptionKeyProvider.generateKey())
        case .failure(let error):
            Issue.record("Unexpected failure: \(error)")
        }
    }
    
    @Test("Logging in with a password to an account that is already logged in fails and logs out the new session")
    mutating func passwordLoginWithExistingAccount() async throws {
        try await setup(serverNameOrBaseURL: "example.com")
        userSessionManager.userIDs = ["@alice:example.com"]
        try await service.configure(for: "example.com", flow: .login).get()
        
        let result = await service.login(username: "alice", password: "12345678", initialDeviceName: nil, deviceID: nil)
        
        #expect(throws: AuthenticationServiceError.accountAlreadyLoggedIn(userID: "@alice:example.com")) { try result.get() }
        #expect(client.logoutCallsCount == 1)
        #expect(!userSessionManager.userSessionForSessionDirectoriesPassphraseCalled)
    }
    
    @Test("Logging in with OAuth to an account that is already logged in fails and logs out the new session")
    mutating func oAuthLoginWithExistingAccount() async throws {
        try await setup()
        userSessionManager.userIDs = ["@alice:matrix.org"]
        client.userIdReturnValue = "@alice:matrix.org"
        try await service.configure(for: "matrix.org", flow: .login).get()
        
        let result = await service.loginWithOAuthCallback("https://example.com/callback")
        
        #expect(throws: AuthenticationServiceError.accountAlreadyLoggedIn(userID: "@alice:matrix.org")) { try result.get() }
        #expect(client.logoutCallsCount == 1)
        #expect(!userSessionManager.userSessionForSessionDirectoriesPassphraseCalled)
    }
    
    @Test("Configuring a server forces native password login")
    mutating func configureLoginWithPassword() async throws {
        try await setup()
        
        try await service.configure(for: "matrix.org", flow: .login).get()
        
        #expect(service.flow == .login)
        #expect(service.homeserver.value == LoginHomeserver(accountProvider: .generic("matrix.org"), loginMode: .password))
    }
    
    @Test("Configuring a server for registration keeps native password mode")
    mutating func configureRegisterWithPassword() async throws {
        try await setup()
        
        try await service.configure(for: "matrix.org", flow: .register).get()
        
        #expect(service.flow == .register)
        #expect(service.homeserver.value == LoginHomeserver(accountProvider: .generic("matrix.org"), loginMode: .password))
    }
    
    @Test("Resetting the service restores the default login state")
    mutating func reset() async throws {
        try await setup(serverNameOrBaseURL: "company.com")
        try await service.configure(for: "company.com", flow: .register).get()
        
        #expect(service.flow == .register)
        #expect(service.homeserver.value.loginMode == .password)
        #expect(targetContext.statePublisher.value.authenticationHomeserver == .discovered("https://matrix.company.com"))
        
        service.reset()
        
        #expect(service.flow == .login)
        #expect(service.homeserver.value == LoginHomeserver(accountProvider: appSettings.defaultAccountProvider, loginMode: .unknown))
        #expect(targetContext.statePublisher.value.authenticationHomeserver == .undiscovered)
    }
    
    // MARK: - Helpers
    
    private mutating func setup(serverNameOrBaseURL: String = "matrix.org") async throws {
        let configuration = ClientFactoryMock.Configuration()
        let clientFactory = ClientFactoryMock(configuration)
        
        client = try #require(configuration.homeserverClients[serverNameOrBaseURL])
        encryption = EncryptionSDKMock()
        client.encryptionReturnValue = encryption
        
        userSessionManager = UserSessionManagerMock(.init())
        encryptionKeyProvider = MockEncryptionKeyProvider()
        appSettings = .volatile()
        targetContext = .mock
        
        service = AuthenticationService(userSessionManager: userSessionManager,
                                        encryptionKeyProvider: encryptionKeyProvider,
                                        clientFactory: clientFactory,
                                        appSettings: appSettings,
                                        appHooks: AppHooks(),
                                        targetContext: targetContext)
    }
}

struct MockEncryptionKeyProvider: EncryptionKeyProviderProtocol {
    private let key = "12345678"
    
    func generateKey() -> Data {
        Data(key.utf8)
    }
}
