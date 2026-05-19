//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

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

            switch await authenticationService.login(username: email,
                                                     password: state.bindings.password,
                                                     initialDeviceName: UIDevice.current.initialDeviceName,
                                                     deviceID: nil) {
            case .success(let userSession):
                actionsSubject.send(.signedIn(userSession))
                stopLoading()
            case .failure(let error):
                stopLoading()
                handleError(error)
            }
        }
    }
    
    private static let loadingIndicatorIdentifier = "\(LoginScreenCoordinatorAction.self)-Loading"
    
    private func startLoading() {
        state.isLoading = true
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    /// Processes an error to either update the flow or display it to the user.
    private func handleError(_ error: AuthenticationServiceError) {
        MXLog.info("Error occurred: \(error)")
        
        switch error {
        case .invalidCredentials:
            state.bindings.alertInfo = AlertInfo(id: .credentialsAlert,
                                                 title: L10n.commonError,
                                                 message: UntranslatedL10n.screenLoginErrorInvalidCredentials)
        case .accountDeactivated:
            state.bindings.alertInfo = AlertInfo(id: .deactivatedAlert,
                                                 title: L10n.commonError,
                                                 message: L10n.screenLoginErrorDeactivatedAccount)
        case .invalidWellKnown(let error):
            state.bindings.alertInfo = AlertInfo(id: .slidingSyncAlert,
                                                 title: L10n.commonServerNotSupported,
                                                 message: L10n.screenChangeServerErrorInvalidWellKnown(error))
        case .slidingSyncNotAvailable:
            let nonBreakingAppName = InfoPlistReader.main.bundleDisplayName.replacingOccurrences(of: " ", with: "\u{00A0}")
            state.bindings.alertInfo = AlertInfo(id: .slidingSyncAlert,
                                                 title: L10n.commonServerNotSupported,
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
                                                 secondaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil))
            // Clear out the invalid email to avoid an attempted login to the default homeserver.
            state.bindings.email = ""
        case .sessionTokenRefreshNotSupported:
            state.bindings.alertInfo = AlertInfo(id: .refreshTokenAlert,
                                                 title: L10n.commonServerNotSupported,
                                                 message: L10n.screenLoginErrorRefreshTokens)
        default:
            state.bindings.alertInfo = AlertInfo(id: .unknown)
        }
    }
}
