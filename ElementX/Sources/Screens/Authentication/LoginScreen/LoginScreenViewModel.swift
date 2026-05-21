//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI
import UIKit

typealias LoginScreenViewModelType = StateStoreViewModelV2<LoginScreenViewState, LoginScreenViewAction>

class LoginScreenViewModel: LoginScreenViewModelType, LoginScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let appSettings: AppSettings
    
    private var actionsSubject: PassthroughSubject<LoginScreenViewModelAction, Never> = .init()
    var actions: AnyPublisher<LoginScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: AuthenticationServiceProtocol,
         loginHint: String?,
         userIndicatorController: UserIndicatorControllerProtocol,
         appSettings: AppSettings) {
        self.authenticationService = authenticationService
        self.userIndicatorController = userIndicatorController
        self.appSettings = appSettings

        let email = loginHint ?? ""

        let viewState = LoginScreenViewState(homeserver: authenticationService.homeserver.value,
                                             bindings: LoginScreenBindings(email: email))
        
        super.init(initialViewState: viewState)
        
        authenticationService.homeserver
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.homeserver, on: self)
            .store(in: &cancellables)
    }

    override func process(viewAction: LoginScreenViewAction) {
        switch viewAction {
        case .next:
            login()
        case .back:
            goBack()
        case .resendVerificationCode:
            resendVerificationCode()
        }
    }
    
    func stopLoading() {
        state.isLoading = false
        userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorIdentifier)
    }
    
    // MARK: - Private
    
    /// Requests the authentication coordinator to log in using the specified credentials.
    private func login() {
        MXLog.info("Starting login with email and password.")
        startLoading()

        Task {
            let email = state.bindings.email.trimmingCharacters(in: .whitespacesAndNewlines)
            switch state.step {
            case .credentials:
                switch await authenticationService.startNativeLogin(login: email,
                                                                    password: state.bindings.password) {
                case .success(let pendingLogin):
                    state.pendingLogin = pendingLogin
                    state.step = .verificationCode
                    state.bindings.password = ""
                    state.bindings.verificationCode = ""
                case .failure(let error):
                    handleError(error)
                }
                stopLoading()
            case .verificationCode:
                guard let pendingLogin = state.pendingLogin else {
                    stopLoading()
                    state.step = .credentials
                    return
                }
                switch await authenticationService.continueNativeLogin(pendingLogin,
                                                                       verificationCode: state.bindings.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines),
                                                                       initialDeviceName: UIDevice.current.initialDeviceName,
                                                                       deviceID: nil) {
                case .success(let userSession):
                    actionsSubject.send(.signedIn(userSession))
                case .failure(let error):
                    handleError(error)
                }
                stopLoading()
            }
        }
    }

    private func resendVerificationCode() {
        guard let pendingLogin = state.pendingLogin else { return }
        startLoading()

        Task {
            switch await authenticationService.resendNativeLoginCode(pendingLogin) {
            case .success(let updatedPendingLogin):
                state.pendingLogin = updatedPendingLogin
                stopLoading()
            case .failure(let error):
                stopLoading()
                handleError(error)
            }
        }
    }

    private func goBack() {
        switch state.step {
        case .credentials:
            actionsSubject.send(.cancel)
        case .verificationCode:
            state.step = .credentials
            state.bindings.verificationCode = ""
        }
    }
    
    private static let loadingIndicatorIdentifier = "\(LoginScreenCoordinatorAction.self)-Loading"
    
    private func startLoading() {
        state.isLoading = true
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal,
                                                              title: ArcanaLocalization.loading,
                                                              persistent: true))
    }
    
    /// Processes an error to either update the flow or display it to the user.
    private func handleError(_ error: AuthenticationServiceError) {
        MXLog.info("Error occurred: \(error)")
        
        switch error {
        case .invalidCredentials:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginInvalidCredentials)
        case .invalidVerificationCode:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginInvalidVerificationCode)
        case .rateLimited(let retryAfterMs):
            let retryMessage = retryAfterMs.map { Int($0 / 1000) } ?? 0
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginRateLimited(seconds: retryMessage))
        case .accountDeactivated:
            state.bindings.alertInfo = AlertInfo(id: .deactivatedAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: L10n.screenLoginErrorDeactivatedAccount)
        case .invalidWellKnown(let error):
            state.bindings.alertInfo = AlertInfo(id: .slidingSyncAlert,
                                                 title: ArcanaLocalization.serverNotSupported,
                                                 message: L10n.screenChangeServerErrorInvalidWellKnown(error))
        case .slidingSyncNotAvailable:
            let nonBreakingAppName = InfoPlistReader.main.bundleDisplayName.replacingOccurrences(of: " ", with: "\u{00A0}")
            state.bindings.alertInfo = AlertInfo(id: .slidingSyncAlert,
                                                 title: ArcanaLocalization.serverNotSupported,
                                                 message: L10n.screenChangeServerErrorNoSlidingSyncMessage(nonBreakingAppName))
            
            // Clear out the invalid email to avoid an attempted login to the default homeserver.
            state.bindings.email = ""
        case .elementProRequired(let serverName):
            state.bindings.alertInfo = AlertInfo(id: .elementProAlert,
                                                 title: L10n.screenChangeServerErrorElementProRequiredTitle,
                                                 message: L10n.screenChangeServerErrorElementProRequiredMessage(serverName),
                                                 primaryButton: .init(title: L10n.screenChangeServerErrorElementProRequiredActionIos) {
                                                     UIApplication.shared.open(self.appSettings.elementProAppStoreURL)
                                                 },
                                                 secondaryButton: .init(title: ArcanaLocalization.cancelAction, role: .cancel, action: nil))
            // Clear out the invalid email to avoid an attempted login to the default homeserver.
            state.bindings.email = ""
        case .sessionTokenRefreshNotSupported:
            state.bindings.alertInfo = AlertInfo(id: .refreshTokenAlert,
                                                 title: ArcanaLocalization.serverNotSupported,
                                                 message: L10n.screenLoginErrorRefreshTokens)
        case .emailVerificationUnavailable:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginEmailVerificationUnavailable)
        case .invalidEmail:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginInvalidEmail)
        case .emailAlreadyInUse:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginEmailAlreadyInUse)
        case .invalidUsername:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginInvalidUsername)
        case .usernameInUse:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginUsernameInUse)
        case .invalidRegistrationToken:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.loginInvalidRegistrationToken)
        default:
            state.bindings.alertInfo = AlertInfo(id: .unknown)
        }
    }
}
