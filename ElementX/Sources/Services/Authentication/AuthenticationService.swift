//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

class AuthenticationService: AuthenticationServiceProtocol {
    var client: ClientProtocol?
    private var sessionDirectories: SessionDirectories
    private let passphrase: Data
    
    private let userSessionManager: UserSessionManagerProtocol
    private let clientFactory: ClientFactoryProtocol
    private let appSettings: AppSettings
    private let appHooks: AppHooks
    private let targetContext: Target.Context
    
    private let homeserverSubject: CurrentValueSubject<LoginHomeserver, Never>
    /// The currently configured homeserver.
    ///
    /// **Note:** The value's `accountProvider` will always be `.generic` after calling `configure(for:flow:)`.
    var homeserver: CurrentValuePublisher<LoginHomeserver, Never> {
        homeserverSubject.asCurrentValuePublisher()
    }
    
    private(set) var flow: AuthenticationFlow
    
    init(userSessionManager: UserSessionManagerProtocol,
         encryptionKeyProvider: EncryptionKeyProviderProtocol,
         clientFactory: ClientFactoryProtocol = ClientFactory(),
         appSettings: AppSettings,
         appHooks: AppHooks,
         targetContext: Target.Context) {
        sessionDirectories = .init()
        passphrase = encryptionKeyProvider.generateKey()
        
        self.userSessionManager = userSessionManager
        self.clientFactory = clientFactory
        self.appSettings = appSettings
        self.appHooks = appHooks
        self.targetContext = targetContext
        
        // When updating these, don't forget to update the reset method too.
        homeserverSubject = .init(LoginHomeserver(accountProvider: appSettings.defaultAccountProvider, loginMode: .unknown))
        flow = .login
    }
    
    // MARK: - Public
    
    func configure(for serverNameOrBaseURL: String, flow: AuthenticationFlow) async -> Result<Void, AuthenticationServiceError> {
        do {
            var homeserver = LoginHomeserver(accountProvider: .generic(serverNameOrBaseURL), loginMode: .unknown)
            
            let client = try await makeClient(serverNameOrBaseURL: serverNameOrBaseURL)
            // Arcana only offers native email/password auth on a fixed homeserver.
            // Forcing password mode keeps the login form and native registration available
            // even when the server also advertises OAuth.
            homeserver.loginMode = .password
            
            self.client = client
            self.flow = flow
            homeserverSubject.send(homeserver)
            return .success(())
        } catch ClientBuildError.WellKnownDeserializationError(let error) {
            MXLog.error("The user entered a server with an invalid well-known file: \(error)")
            return .failure(.invalidWellKnown(error))
        } catch ClientBuildError.SlidingSyncVersion(let error) {
            MXLog.info("User entered a homeserver that isn't configured for sliding sync: \(error)")
            return .failure(.slidingSyncNotAvailable)
        } catch ClientFactoryError.elementProRequired(let serverName) {
            return .failure(.elementProRequired(serverName: serverName))
        } catch {
            MXLog.error("Failed configuring a server: \(error)")
            return .failure(.invalidServerNameOrBaseURL)
        }
    }
    
    func urlForOAuthLogin(loginHint: String?) async -> Result<OAuthAuthorizationDataProxy, AuthenticationServiceError> {
        guard let client else { return .failure(.oAuthError(.urlFailure)) }
        do {
            let supportsCreatePrompt = homeserverSubject.value.loginMode == .oAuth(supportsCreatePrompt: true)
            let prompt: OAuthPrompt = flow == .register && supportsCreatePrompt ? .create : .consent
            let oAuthData = try await client.urlForOauth(oauthConfiguration: appSettings.oAuthConfiguration.rustValue,
                                                         prompt: prompt,
                                                         loginHint: loginHint,
                                                         deviceId: nil,
                                                         additionalScopes: nil)
            return .success(OAuthAuthorizationDataProxy(underlyingData: oAuthData, homeserver: client.homeserver()))
        } catch {
            MXLog.error("Failed to get URL for OAuth login: \(error)")
            return .failure(.oAuthError(.urlFailure))
        }
    }
    
    func abortOAuthLogin(data: OAuthAuthorizationDataProxy) async {
        guard let client else { return }
        MXLog.info("Aborting OAuth login.")
        await client.abortOauthAuth(authorizationData: data.underlyingData)
    }
    
    func loginWithOAuthCallback(_ callbackURL: URL) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        guard let client else { return .failure(.failedLoggingIn) }
        do {
            try await client.loginWithOauthCallback(callbackUrl: callbackURL.absoluteString)
            return await userSession(for: client)
        } catch MatrixRustSDK.OAuthError.Cancelled {
            return .failure(.oAuthError(.userCancellation))
        } catch {
            MXLog.error("Login with OAuth failed: \(error)")
            return .failure(.failedLoggingIn)
        }
    }
    
    func login(username: String, password: String, initialDeviceName: String?, deviceID: String?) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        guard let client else { return .failure(.failedLoggingIn) }
        do {
            try await client.login(username: username, password: password, initialDeviceName: initialDeviceName, deviceId: deviceID)
            
            let refreshToken = try? client.session().refreshToken
            if refreshToken != nil {
                MXLog.warning("Refresh token found for a non OAuth session, can't restore session, logging out")
                _ = try? await client.logout()
                return .failure(.sessionTokenRefreshNotSupported)
            }
            
            return await userSession(for: client)
        } catch let ClientError.MatrixApi(errorKind, _, _, _) {
            MXLog.error("Failed logging in with error kind: \(errorKind)")
            switch errorKind {
            case .forbidden:
                return .failure(.invalidCredentials)
            case .userDeactivated:
                return .failure(.accountDeactivated)
            default:
                return .failure(.failedLoggingIn)
            }
        } catch {
            MXLog.error("Failed logging in with error: \(error)")
            return .failure(.failedLoggingIn)
        }
    }
    
    func loginWithQRCode(data: Data) -> QRLoginOperation {
        let progressSubject = CurrentValueSubject<QRLoginProgress, AuthenticationServiceError>(.starting)
        
        let qrData: QrCodeData
        do {
            qrData = try QrCodeData.fromBytes(bytes: data)
        } catch {
            MXLog.error("QRCode decode error: \(error)")
            progressSubject.send(completion: .failure(.qrCodeError(.invalidQRCode)))
            return QRLoginOperation(progressPublisher: progressSubject.asCurrentValuePublisher())
        }
        
        // n.b. We rely on the SDK checking that the intent of the QR is suitable for us to login with.
        
        // Future versions of the QR should always give us the baseURL
        guard let scannedServerNameOrBaseURL = qrData.baseUrl() ?? qrData.serverName() else {
            // With the older version of QR we treat the presence of serverName as meaning that the other device
            // is not signed in.
            MXLog.error("The QR code is from a device that is not yet signed in.")
            progressSubject.send(completion: .failure(.qrCodeError(.deviceNotSignedIn)))
            return QRLoginOperation(progressPublisher: progressSubject.asCurrentValuePublisher())
        }
        
        // When account provider selection is restricted, make sure the scanned server is allowed.
        // However, generic providers aren't detailed enough, so continue if one is present.
        if !appSettings.allowOtherAccountProviders, !appSettings.accountProviders.contains(where: \.isGeneric) {
            // A base URL from the QR code is expected to be a valid URL when present.
            let scannedBaseURL = qrData.baseUrl().flatMap(URL.init(string:))
            
            guard appSettings.accountProviders.contains(serverName: qrData.serverName(), orBaseURL: scannedBaseURL) else {
                MXLog.error("The scanned QR code is for an account provider that isn't allowed.")
                let error = QRCodeLoginError.providerNotAllowed(scannedProvider: scannedServerNameOrBaseURL,
                                                                allowedProviders: appSettings.accountProviders.map(\.serverNameOrBaseURL))
                progressSubject.send(completion: .failure(.qrCodeError(error)))
                return QRLoginOperation(progressPublisher: progressSubject.asCurrentValuePublisher())
            }
        }
        
        // The SDK calls the listener from arbitrary threads; onMainActor forwards the progress
        // updates on the main actor in FIFO order.
        let listener = SDKListener.onMainActor { rustProgress in
            guard let progress = QRLoginProgress(rustProgress: rustProgress) else { return }
            progressSubject.send(progress)
        }
        
        let task = Task {
            do {
                let client = try await makeClient(serverNameOrBaseURL: scannedServerNameOrBaseURL)
                let qrCodeHandler = client.newLoginWithQrCodeHandler(oauthConfiguration: appSettings.oAuthConfiguration.rustValue)
                let sdkTask = try qrCodeHandler.scan(qrCodeData: qrData, progressListener: listener)
                try await withTaskCancellationHandler(operation: sdkTask.wait, onCancel: sdkTask.cancel)
                
                switch await userSession(for: client) {
                case .success(let userSession):
                    // Since the QR code login flow includes verification.
                    userSession.userSettings.account.hasRunIdentityConfirmationOnboarding = true
                    progressSubject.send(.signedIn(userSession))
                case .failure(let error):
                    progressSubject.send(completion: .failure(error))
                }
            } catch let error as HumanQrLoginError {
                MXLog.error("QRCode login error: \(error)")
                progressSubject.send(completion: .failure(error.serviceError))
            } catch ClientFactoryError.elementProRequired(let serverName) {
                progressSubject.send(completion: .failure(.elementProRequired(serverName: serverName)))
            } catch {
                MXLog.error("QRCode login unknown error: \(error)")
                progressSubject.send(completion: .failure(.qrCodeError(.unknown)))
            }
        }
        
        return QRLoginOperation(progressPublisher: progressSubject.asCurrentValuePublisher(), task: task)
    }
    
    func reset() {
        homeserverSubject.send(LoginHomeserver(accountProvider: appSettings.defaultAccountProvider, loginMode: .unknown))
        flow = .login
        client = nil
        targetContext.startAuthentication()
    }
    
    // MARK: - Private
    
    private func makeClient(serverNameOrBaseURL: String) async throws -> ClientProtocol {
        // Use a fresh session directory each time the user enters a different server
        // so that caches (e.g. server versions) are always fresh for the new server.
        rotateSessionDirectory()
        
        let client = try await clientFactory.makeAuthenticationClient(serverNameOrBaseURL: serverNameOrBaseURL,
                                                                      sessionDirectories: sessionDirectories,
                                                                      passphrase: passphrase,
                                                                      clientSessionDelegate: userSessionManager.clientSessionDelegate,
                                                                      appSettings: appSettings,
                                                                      appHooks: appHooks)
        try await appHooks.clientFactoryHook.validateAuthenticationHomeserver(for: client)
        targetContext.updateAuthentication(homeserver: client.homeserver())
        let updatedClient = await appHooks.clientFactoryHook.updateAuthenticationClient(client)
        
        return appHooks.authenticationServiceHook.updateClient(updatedClient)
    }
    
    private func rotateSessionDirectory() {
        try? sessionDirectories.delete()
        sessionDirectories = .init()
    }
    
    /// Internal so `AuthenticationService+NativeAuth` can finish a restored email session.
    func userSession(for client: ClientProtocol) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        let userID: String
        do {
            userID = try client.userId()
        } catch {
            MXLog.error("Failed getting the user ID after logging in: \(error)")
            return .failure(.failedLoggingIn)
        }
        
        if userSessionManager.userIDs.contains(userID) {
            MXLog.warning("There's already an account logged in as \(userID), logging out the new session.")
            _ = try? await client.logout()
            rotateSessionDirectory()
            return .failure(.accountAlreadyLoggedIn(userID: userID))
        }
        
        switch await userSessionManager.userSession(for: client, sessionDirectories: sessionDirectories, passphrase: passphrase) {
        case .success(let clientProxy):
            return .success(clientProxy)
        case .failure:
            return .failure(.failedLoggingIn)
        }
    }
}

private extension HumanQrLoginError {
    var serviceError: AuthenticationServiceError {
        switch self {
        case .Cancelled:
            .qrCodeError(.cancelled)
        case .ConnectionInsecure:
            .qrCodeError(.connectionInsecure)
        case .Declined:
            .qrCodeError(.declined)
        case .LinkingNotSupported:
            .qrCodeError(.linkingNotSupported)
        case .Expired, .NotFound: // The most likely cause of a .NotFound is that the rendezvous session expired on the server side
            .qrCodeError(.expired)
        case .SlidingSyncNotAvailable:
            .qrCodeError(.slidingSyncNotAvailable)
        case .OtherDeviceNotSignedIn:
            .qrCodeError(.deviceNotSignedIn)
        case .UnsupportedQrCodeType:
            .qrCodeError(.invalidQRCode)
        case .Unknown, .OAuthMetadataInvalid, .CheckCodeAlreadySent, .CheckCodeCannotBeSent, .ContinuationAlreadySent, .ContinuationCannotBeSent:
            .qrCodeError(.unknown)
        }
    }
}

// MARK: - Mocks

extension AuthenticationService {
    static var mock: AuthenticationService {
        AuthenticationService(userSessionManager: UserSessionManagerMock(.init()),
                              encryptionKeyProvider: EncryptionKeyProvider(),
                              clientFactory: ClientFactoryMock(.init()),
                              appSettings: .volatile(),
                              appHooks: AppHooks(),
                              targetContext: .mock)
    }
}
