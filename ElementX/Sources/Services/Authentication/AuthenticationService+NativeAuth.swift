//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK
import UIKit

private struct NativeAuthSessionResponse: Decodable {
    let userID: String
    let accessToken: String
    let deviceID: String
    let homeServer: String?
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case accessToken = "access_token"
        case deviceID = "device_id"
        case homeServer = "home_server"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct NativeAuthSidResponse: Decodable {
    let sid: String
    let email: String?
}

private struct NativeAuthSidOnlyResponse: Decodable {
    let sid: String
}

private struct NativeAuthEmptyResponse: Decodable { }

private struct NativeAuthErrorResponse: Decodable {
    let errcode: String?
    let error: String?
    let retryAfterMs: Int?

    enum CodingKeys: String, CodingKey {
        case errcode
        case error
        case retryAfterMs = "retry_after_ms"
    }
}

private struct NativeAuthLoginStartRequest: Encodable {
    let clientSecret: String
    let login: String
    let password: String
    let sendAttempt: Int

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case login
        case password
        case sendAttempt = "send_attempt"
    }
}

private struct NativeAuthLoginContinueRequest: Encodable {
    let clientSecret: String
    let sid: String
    let token: String
    let deviceID: String?
    let initialDeviceDisplayName: String?

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case sid
        case token
        case deviceID = "device_id"
        case initialDeviceDisplayName = "initial_device_display_name"
    }
}

private struct NativeAuthRegistrationEmailRequest: Encodable {
    let clientSecret: String
    let email: String
    let sendAttempt: Int

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case email
        case sendAttempt = "send_attempt"
    }
}

private struct NativeAuthRegistrationCodeRequest: Encodable {
    let clientSecret: String
    let sid: String
    let token: String

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case sid
        case token
    }
}

private struct NativeAuthRegistrationFinishRequest: Encodable {
    let email: String
    let clientSecret: String
    let sid: String
    let password: String
    let username: String?
    let deviceID: String?
    let initialDeviceDisplayName: String
    let inhibitLogin: Bool

    enum CodingKeys: String, CodingKey {
        case email
        case clientSecret = "client_secret"
        case sid
        case password
        case username
        case deviceID = "device_id"
        case initialDeviceDisplayName = "initial_device_display_name"
        case inhibitLogin = "inhibit_login"
    }
}

private struct NativeAuthPasswordResetFinishRequest: Encodable {
    let password: String
    let clientSecret: String
    let sid: String
    let logoutDevices: Bool

    enum CodingKeys: String, CodingKey {
        case password
        case clientSecret = "client_secret"
        case sid
        case logoutDevices = "logout_devices"
    }
}

private struct NativeAuthRequest<Body: Encodable, Response: Decodable> {
    let path: String
    let body: Body
    let responseType: Response.Type
}

extension AuthenticationService {
    func startNativeLogin(login: String, password: String) async -> Result<PendingNativeLogin, AuthenticationServiceError> {
        guard let homeserverURL = nativeAuthHomeserverURL else { return .failure(.failedLoggingIn) }
        let pendingLogin = PendingNativeLogin(homeserverUrl: homeserverURL,
                                              login: login.trimmingCharacters(in: .whitespacesAndNewlines),
                                              password: password,
                                              clientSecret: UUID().uuidString,
                                              sendAttempt: 1,
                                              sid: nil,
                                              email: nil)

        do {
            let response: NativeAuthSidResponse = try await performNativeAuthRequest(path: "_matrix/client/v3/login",
                                                                                     body: NativeAuthLoginStartRequest(clientSecret: pendingLogin.clientSecret,
                                                                                                                       login: pendingLogin.login,
                                                                                                                       password: pendingLogin.password,
                                                                                                                       sendAttempt: pendingLogin.sendAttempt))

            guard let email = response.email else {
                return .failure(.emailVerificationUnavailable)
            }

            return .success(pendingLogin.with(sid: response.sid, email: email))
        } catch let error as NativeAuthFailure {
            return .failure(error.serviceError)
        } catch {
            MXLog.error("Failed starting native login: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func continueNativeLogin(_ pendingLogin: PendingNativeLogin, verificationCode: String, initialDeviceName: String?, deviceID: String?) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        guard let client else { return .failure(.failedLoggingIn) }
        do {
            let deviceName: String
            if let initialDeviceName {
                deviceName = initialDeviceName
            } else {
                deviceName = await MainActor.run {
                    UIDevice.current.initialDeviceName
                }
            }
            let response: NativeAuthSessionResponse = try await performNativeAuthRequest(baseURL: pendingLogin.homeserverUrl,
                                                                                         path: "_matrix/client/v3/login",
                                                                                         body: NativeAuthLoginContinueRequest(clientSecret: pendingLogin.clientSecret,
                                                                                                                              sid: requireNonNil(pendingLogin.sid),
                                                                                                                              token: verificationCode,
                                                                                                                              deviceID: deviceID,
                                                                                                                              initialDeviceDisplayName: deviceName))

            try await restoreNativeSession(response: response, client: client, fallbackHomeserverURL: pendingLogin.homeserverUrl)
            // Arcana: email OTP + password proves ownership — bootstrap cross-signing so this
            // device is verified and encrypted sends are not wedged.
            return await completeNativeSession(client: client, identityBootstrapPassword: pendingLogin.password)
        } catch let error as NativeAuthFailure {
            return .failure(error.loginVerificationServiceError)
        } catch {
            MXLog.error("Failed completing native login: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func resendNativeLoginCode(_ pendingLogin: PendingNativeLogin) async -> Result<PendingNativeLogin, AuthenticationServiceError> {
        guard nativeAuthHomeserverURL != nil else { return .failure(.failedLoggingIn) }
        let updated = pendingLogin.resending()

        do {
            let response: NativeAuthSidResponse = try await performNativeAuthRequest(baseURL: updated.homeserverUrl,
                                                                                     path: "_matrix/client/v3/login",
                                                                                     body: NativeAuthLoginStartRequest(clientSecret: updated.clientSecret,
                                                                                                                       login: updated.login,
                                                                                                                       password: updated.password,
                                                                                                                       sendAttempt: updated.sendAttempt))
            return .success(updated.with(sid: response.sid, email: response.email ?? updated.email))
        } catch let error as NativeAuthFailure {
            return .failure(error.serviceError)
        } catch {
            MXLog.error("Failed resending native login code: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func startNativeRegistration(email: String) async -> Result<PendingNativeRegistration, AuthenticationServiceError> {
        guard let homeserverURL = nativeAuthHomeserverURL else {
            MXLog.error("Native registration started without a configured client/homeserver")
            return .failure(.failedLoggingIn)
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            return .failure(.invalidEmail)
        }
        let pendingRegistration = PendingNativeRegistration(homeserverUrl: homeserverURL,
                                                            email: trimmedEmail,
                                                            clientSecret: UUID().uuidString,
                                                            sendAttempt: 1,
                                                            sid: nil)
        do {
            let response: NativeAuthSidOnlyResponse = try await performNativeAuthRequest(path: "_matrix/client/v3/register/email/requestToken",
                                                                                         body: NativeAuthRegistrationEmailRequest(clientSecret: pendingRegistration.clientSecret,
                                                                                                                                  email: pendingRegistration.email,
                                                                                                                                  sendAttempt: pendingRegistration.sendAttempt))
            return .success(pendingRegistration.with(sid: response.sid))
        } catch let error as NativeAuthFailure {
            return .failure(error.serviceError)
        } catch {
            MXLog.error("Failed starting native registration: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func continueNativeRegistrationEmailCode(_ pendingRegistration: PendingNativeRegistration, verificationCode: String) async -> Result<PendingNativeRegistration, AuthenticationServiceError> {
        do {
            let response: NativeAuthSidOnlyResponse = try await performNativeAuthRequest(baseURL: pendingRegistration.homeserverUrl,
                                                                                         path: "_matrix/client/v3/register/email/submitToken",
                                                                                         body: NativeAuthRegistrationCodeRequest(clientSecret: pendingRegistration.clientSecret,
                                                                                                                                 sid: requireNonNil(pendingRegistration.sid),
                                                                                                                                 token: verificationCode))
            return .success(pendingRegistration.with(sid: response.sid))
        } catch let error as NativeAuthFailure {
            return .failure(error.registrationVerificationServiceError)
        } catch {
            MXLog.error("Failed confirming native registration email: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func finishNativeRegistration(_ pendingRegistration: PendingNativeRegistration, username: String?, password: String, initialDeviceName: String?, deviceID: String?) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        guard let client else {
            MXLog.error("Native registration finish called without a configured client")
            return .failure(.failedLoggingIn)
        }
        do {
            let deviceName: String
            if let initialDeviceName {
                deviceName = initialDeviceName
            } else {
                deviceName = await MainActor.run {
                    UIDevice.current.initialDeviceName
                }
            }
            let response: NativeAuthSessionResponse = try await performNativeAuthRequest(baseURL: pendingRegistration.homeserverUrl,
                                                                                         path: "_matrix/client/v3/register",
                                                                                         body: NativeAuthRegistrationFinishRequest(email: pendingRegistration.email,
                                                                                                                                   clientSecret: pendingRegistration.clientSecret,
                                                                                                                                   sid: requireNonNil(pendingRegistration.sid),
                                                                                                                                   password: password,
                                                                                                                                   username: username.flatMap { trimmedUsername in
                                                                                                                                       let candidate = trimmedUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                                                                                                                                       return candidate.isBlank ? nil : candidate
                                                                                                                                   },
                                                                                                                                   deviceID: deviceID,
                                                                                                                                   initialDeviceDisplayName: deviceName,
                                                                                                                                   inhibitLogin: false))

            try await restoreNativeSession(response: response, client: client, fallbackHomeserverURL: pendingRegistration.homeserverUrl)
            return await completeNativeSession(client: client, identityBootstrapPassword: password)
        } catch let error as NativeAuthFailure {
            return .failure(error.serviceError)
        } catch {
            MXLog.error("Failed completing native registration: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func resendNativeRegistrationEmail(_ pendingRegistration: PendingNativeRegistration) async -> Result<PendingNativeRegistration, AuthenticationServiceError> {
        let updated = pendingRegistration.resending()
        do {
            let response: NativeAuthSidOnlyResponse = try await performNativeAuthRequest(baseURL: updated.homeserverUrl,
                                                                                         path: "_matrix/client/v3/register/email/requestToken",
                                                                                         body: NativeAuthRegistrationEmailRequest(clientSecret: updated.clientSecret,
                                                                                                                                  email: updated.email,
                                                                                                                                  sendAttempt: updated.sendAttempt))
            return .success(updated.with(sid: response.sid))
        } catch let error as NativeAuthFailure {
            return .failure(error.serviceError)
        } catch {
            MXLog.error("Failed resending native registration email: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func startNativePasswordReset(email: String) async -> Result<PendingNativePasswordReset, AuthenticationServiceError> {
        guard let homeserverURL = nativeAuthHomeserverURL else { return .failure(.failedLoggingIn) }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            return .failure(.invalidEmail)
        }

        let pendingPasswordReset = PendingNativePasswordReset(homeserverUrl: homeserverURL,
                                                              email: trimmedEmail,
                                                              clientSecret: UUID().uuidString,
                                                              sendAttempt: 1,
                                                              sid: nil)
        do {
            let response: NativeAuthSidOnlyResponse = try await performNativeAuthRequest(path: "_matrix/client/v3/account/password/email/requestToken",
                                                                                         body: NativeAuthRegistrationEmailRequest(clientSecret: pendingPasswordReset.clientSecret,
                                                                                                                                  email: pendingPasswordReset.email,
                                                                                                                                  sendAttempt: pendingPasswordReset.sendAttempt))
            return .success(pendingPasswordReset.with(sid: response.sid))
        } catch let error as NativeAuthFailure {
            return .failure(error.serviceError)
        } catch {
            MXLog.error("Failed starting native password reset: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func continueNativePasswordResetEmailCode(_ pendingPasswordReset: PendingNativePasswordReset, verificationCode: String) async -> Result<PendingNativePasswordReset, AuthenticationServiceError> {
        do {
            let response: NativeAuthSidOnlyResponse = try await performNativeAuthRequest(baseURL: pendingPasswordReset.homeserverUrl,
                                                                                         path: "_matrix/client/v3/account/password/email/submitToken",
                                                                                         body: NativeAuthRegistrationCodeRequest(clientSecret: pendingPasswordReset.clientSecret,
                                                                                                                                 sid: requireNonNil(pendingPasswordReset.sid),
                                                                                                                                 token: verificationCode))
            return .success(pendingPasswordReset.with(sid: response.sid))
        } catch let error as NativeAuthFailure {
            return .failure(error.registrationVerificationServiceError)
        } catch {
            MXLog.error("Failed confirming native password reset email: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func finishNativePasswordReset(_ pendingPasswordReset: PendingNativePasswordReset, password: String) async -> Result<Void, AuthenticationServiceError> {
        do {
            let _: NativeAuthEmptyResponse = try await performNativeAuthRequest(baseURL: pendingPasswordReset.homeserverUrl,
                                                                                path: "_matrix/client/v3/account/password/email/reset",
                                                                                body: NativeAuthPasswordResetFinishRequest(password: password,
                                                                                                                           clientSecret: pendingPasswordReset.clientSecret,
                                                                                                                           sid: requireNonNil(pendingPasswordReset.sid),
                                                                                                                           logoutDevices: false))
            return .success(())
        } catch let error as NativeAuthFailure {
            return .failure(error.serviceError)
        } catch {
            MXLog.error("Failed completing native password reset: \(error)")
            return .failure(.failedLoggingIn)
        }
    }

    func resendNativePasswordResetEmail(_ pendingPasswordReset: PendingNativePasswordReset) async -> Result<PendingNativePasswordReset, AuthenticationServiceError> {
        let updated = pendingPasswordReset.resending()
        do {
            let response: NativeAuthSidOnlyResponse = try await performNativeAuthRequest(baseURL: updated.homeserverUrl,
                                                                                         path: "_matrix/client/v3/account/password/email/requestToken",
                                                                                         body: NativeAuthRegistrationEmailRequest(clientSecret: updated.clientSecret,
                                                                                                                                  email: updated.email,
                                                                                                                                  sendAttempt: updated.sendAttempt))
            return .success(updated.with(sid: response.sid))
        } catch let error as NativeAuthFailure {
            return .failure(error.serviceError)
        } catch {
            MXLog.error("Failed resending native password reset email: \(error)")
            return .failure(.failedLoggingIn)
        }
    }
}

private extension AuthenticationService {
    var nativeAuthHomeserverURL: String? {
        client?.homeserver()
    }

    func restoreNativeSession(response: NativeAuthSessionResponse, client: ClientProtocol, fallbackHomeserverURL: String) async throws {
        let homeserverURL = response.homeServer
            .flatMap { $0.hasPrefix("http://") || $0.hasPrefix("https://") ? $0 : nil }
            ?? fallbackHomeserverURL
        let session = Session(accessToken: response.accessToken,
                              refreshToken: response.refreshToken,
                              userId: response.userID,
                              deviceId: response.deviceID,
                              homeserverUrl: homeserverURL,
                              oidcData: nil,
                              slidingSyncVersion: .native)
        try await client.restoreSession(session: session)
    }

    /// Restore is done; start sync then bootstrap identity. Cross-signing reset requires E2EE
    /// initialisation, which only happens after the first sync.
    func completeNativeSession(client: ClientProtocol, identityBootstrapPassword: String) async -> Result<UserSessionProtocol, AuthenticationServiceError> {
        let sessionResult = await userSession(for: client)
        if case .success(let userSession) = sessionResult {
            userSession.clientProxy.startSync()
            await ensureDeviceIdentityVerified(client: client, password: identityBootstrapPassword)
        }
        return sessionResult
    }

    /// If the session is not cross-signed yet, reset identity with the account password so this
    /// device becomes the verified owner device (Arcana email-login trust model).
    ///
    /// Must run after sync has started. Do not wait for `.verified` after the reset — that status
    /// can lag until a later sync and previously hung the email-confirm spinner.
    func ensureDeviceIdentityVerified(client: ClientProtocol, password: String) async {
        let encryption = client.encryption()
        await waitForE2eeInitialization(encryption)
        guard encryption.verificationState() != .verified else {
            MXLog.info("Session already verified, skipping identity bootstrap")
            return
        }
        MXLog.info("Bootstrapping crypto identity after email auth")
        do {
            guard let handle = try await encryption.resetIdentity() else {
                MXLog.info("Identity reset completed without interactive auth")
                return
            }
            switch handle.authType() {
            case .uiaa:
                let userID = try client.userId()
                try await handle.reset(auth: .password(passwordDetails: .init(identifier: userID, password: password)))
                MXLog.info("Identity bootstrap with password succeeded")
            case .oidc:
                MXLog.warning("Identity reset requires OIDC — cannot auto-bootstrap for Arcana email login")
                await handle.cancel()
            }
        } catch {
            MXLog.error("Failed bootstrapping identity after email auth: \(error)")
        }
    }

    /// Wait until Olm is ready, or 15s. Status stays `.unknown` until E2EE init after sync.
    func waitForE2eeInitialization(_ encryption: Encryption) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await encryption.waitForE2eeInitializationTasks()
            }
            group.addTask {
                for _ in 0..<60 {
                    if encryption.verificationState() != .unknown { return }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
            await group.next()
            group.cancelAll()
        }
    }

    func performNativeAuthRequest<Body: Encodable, Response: Decodable>(path: String, body: Body) async throws -> Response {
        try await performNativeAuthRequest(baseURL: nativeAuthHomeserverURL, path: path, body: body)
    }

    func performNativeAuthRequest<Body: Encodable, Response: Decodable>(baseURL: String?, path: String, body: Body) async throws -> Response {
        guard let baseURL, let url = URL(string: baseURL)?.appending(path: path) else {
            throw NativeAuthFailure.unavailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NativeAuthFailure.unavailable
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw try mapNativeAuthFailure(from: data, statusCode: httpResponse.statusCode)
                }

                if Response.self == NativeAuthEmptyResponse.self, data.isEmpty {
                    guard let emptyResponse = NativeAuthEmptyResponse() as? Response else {
                        throw NativeAuthFailure.unavailable
                    }
                    return emptyResponse
                }

                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                guard attempt < maxAttempts, error.isTransientNativeAuthNetworkError else {
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
            }
        }

        throw NativeAuthFailure.unavailable
    }

    func mapNativeAuthFailure(from data: Data, statusCode: Int) throws -> NativeAuthFailure {
        let payload = try? JSONDecoder().decode(NativeAuthErrorResponse.self, from: data)
        let errorCode = payload?.errcode

        switch errorCode {
        case "M_FORBIDDEN", "M_UNAUTHORIZED", "M_INVALID_CREDENTIALS":
            return .invalidCredentials
        case "M_INVALID_TOKEN", "M_EMAIL_LOGIN_CODE_EXPIRED":
            return .invalidVerificationCode
        case "M_LIMIT_EXCEEDED":
            return .rateLimited(retryAfterMs: payload?.retryAfterMs)
        case "M_THREEPID_IN_USE":
            return .emailAlreadyInUse
        case "M_THREEPID_DENIED":
            return .invalidEmail
        case "M_INVALID_USERNAME":
            return .invalidUsername
        case "M_USER_IN_USE":
            return .usernameInUse
        case "M_NOT_FOUND":
            return .emailVerificationUnavailable
        case "M_INVALID_REGISTRATION_TOKEN", "M_REGISTRATION_TOKEN_INVALID":
            return .invalidRegistrationToken
        default:
            MXLog.error("Native auth request failed with status \(statusCode) and body \(String(data: data, encoding: .utf8) ?? "<unreadable>")")
            return .message(payload?.error)
        }
    }

    func requireNonNil<T>(_ value: T?) throws -> T {
        guard let value else { throw NativeAuthFailure.unavailable }
        return value
    }
}

private extension Error {
    var isTransientNativeAuthNetworkError: Bool {
        guard let urlError = self as? URLError else {
            return false
        }

        switch urlError.code {
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .networkConnectionLost, .notConnectedToInternet, .timedOut:
            return true
        default:
            return false
        }
    }
}

private enum NativeAuthFailure: Error {
    case unavailable
    case invalidCredentials
    case invalidVerificationCode
    case rateLimited(retryAfterMs: Int?)
    case invalidEmail
    case emailAlreadyInUse
    case invalidUsername
    case usernameInUse
    case emailVerificationUnavailable
    case invalidRegistrationToken
    case message(String?)

    var serviceError: AuthenticationServiceError {
        switch self {
        case .unavailable:
            .failedLoggingIn
        case .invalidCredentials:
            .invalidCredentials
        case .invalidVerificationCode:
            .invalidVerificationCode
        case .rateLimited(let retryAfterMs):
            .rateLimited(retryAfterMs: retryAfterMs)
        case .invalidEmail:
            .invalidEmail
        case .emailAlreadyInUse:
            .emailAlreadyInUse
        case .invalidUsername:
            .invalidUsername
        case .usernameInUse:
            .usernameInUse
        case .emailVerificationUnavailable:
            .emailVerificationUnavailable
        case .invalidRegistrationToken:
            .invalidRegistrationToken
        case .message:
            .failedLoggingIn
        }
    }

    var loginVerificationServiceError: AuthenticationServiceError {
        switch self {
        case .invalidCredentials, .invalidVerificationCode, .message:
            .invalidVerificationCode
        default:
            serviceError
        }
    }

    var registrationVerificationServiceError: AuthenticationServiceError {
        switch self {
        case .invalidCredentials, .invalidVerificationCode, .message:
            .invalidVerificationCode
        default:
            serviceError
        }
    }
}

private extension PendingNativeLogin {
    func with(sid: String, email: String?) -> PendingNativeLogin {
        .init(homeserverUrl: homeserverUrl,
              login: login,
              password: password,
              clientSecret: clientSecret,
              sendAttempt: sendAttempt,
              sid: sid,
              email: email)
    }

    func resending() -> PendingNativeLogin {
        .init(homeserverUrl: homeserverUrl,
              login: login,
              password: password,
              clientSecret: clientSecret,
              sendAttempt: sendAttempt + 1,
              sid: sid,
              email: email)
    }
}

private extension PendingNativeRegistration {
    func with(sid: String) -> PendingNativeRegistration {
        .init(homeserverUrl: homeserverUrl,
              email: email,
              clientSecret: clientSecret,
              sendAttempt: sendAttempt,
              sid: sid)
    }

    func resending() -> PendingNativeRegistration {
        .init(homeserverUrl: homeserverUrl,
              email: email,
              clientSecret: clientSecret,
              sendAttempt: sendAttempt + 1,
              sid: sid)
    }
}

private extension PendingNativePasswordReset {
    func with(sid: String) -> PendingNativePasswordReset {
        .init(homeserverUrl: homeserverUrl,
              email: email,
              clientSecret: clientSecret,
              sendAttempt: sendAttempt,
              sid: sid)
    }

    func resending() -> PendingNativePasswordReset {
        .init(homeserverUrl: homeserverUrl,
              email: email,
              clientSecret: clientSecret,
              sendAttempt: sendAttempt + 1,
              sid: sid)
    }
}
