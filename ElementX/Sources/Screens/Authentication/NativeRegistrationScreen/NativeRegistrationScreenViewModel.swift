//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI
import UIKit

typealias NativeRegistrationScreenViewModelType = StateStoreViewModelV2<NativeRegistrationScreenViewState, NativeRegistrationScreenViewAction>

final class NativeRegistrationScreenViewModel: NativeRegistrationScreenViewModelType, NativeRegistrationScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol

    private var actionsSubject: PassthroughSubject<NativeRegistrationScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<NativeRegistrationScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: AuthenticationServiceProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.authenticationService = authenticationService
        self.userIndicatorController = userIndicatorController

        let viewState = NativeRegistrationScreenViewState()
        super.init(initialViewState: viewState)
    }

    override func process(viewAction: NativeRegistrationScreenViewAction) {
        switch viewAction {
        case .next:
            submit()
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

    private func submit() {
        startLoading()
        Task {
            switch state.step {
            case .email:
                switch await authenticationService.startNativeRegistration(email: state.bindings.email) {
                case .success(let pendingRegistration):
                    state.pendingRegistration = pendingRegistration
                    state.step = .verificationCode
                    state.bindings.verificationCode = ""
                case .failure(let error):
                    handleError(error)
                }
                stopLoading()
            case .verificationCode:
                guard let pendingRegistration = state.pendingRegistration else {
                    stopLoading()
                    state.step = .email
                    return
                }
                switch await authenticationService.continueNativeRegistrationEmailCode(pendingRegistration,
                                                                                       verificationCode: state.bindings.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)) {
                case .success(let updatedPendingRegistration):
                    state.pendingRegistration = updatedPendingRegistration
                    state.step = .credentials
                    state.bindings.verificationCode = ""
                case .failure(let error):
                    handleError(error)
                }
                stopLoading()
            case .credentials:
                guard let pendingRegistration = state.pendingRegistration else {
                    stopLoading()
                    state.step = .email
                    return
                }
                switch await authenticationService.finishNativeRegistration(pendingRegistration,
                                                                            username: state.bindings.username,
                                                                            password: state.bindings.password,
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
        guard let pendingRegistration = state.pendingRegistration else { return }
        startLoading()
        Task {
            switch await authenticationService.resendNativeRegistrationEmail(pendingRegistration) {
            case .success(let updatedPendingRegistration):
                state.pendingRegistration = updatedPendingRegistration
                stopLoading()
            case .failure(let error):
                stopLoading()
                handleError(error)
            }
        }
    }

    private func goBack() {
        switch state.step {
        case .email:
            actionsSubject.send(.cancel)
        case .verificationCode:
            state.step = .email
            state.bindings.verificationCode = ""
        case .credentials:
            state.step = .verificationCode
        }
    }

    private static let loadingIndicatorIdentifier = "\(NativeRegistrationScreenViewModel.self)-Loading"

    private func startLoading() {
        state.isLoading = true
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal,
                                                              title: ArcanaLocalization.loading,
                                                              persistent: true))
    }

    private func handleError(_ error: AuthenticationServiceError) {
        MXLog.info("Registration error occurred: \(error)")

        switch error {
        case .invalidVerificationCode:
            state.bindings.alertInfo = AlertInfo(id: .invalidVerificationCodeAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.nativeRegistrationInvalidCode)
        case .rateLimited(let retryAfterMs):
            let seconds = retryAfterMs.map { max(1, $0 / 1000) } ?? 0
            state.bindings.alertInfo = AlertInfo(id: .rateLimitedAlert("\(seconds)"),
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.nativeRegistrationRateLimited(seconds: seconds))
        case .invalidEmail:
            state.bindings.alertInfo = AlertInfo(id: .invalidEmailAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.nativeRegistrationInvalidEmail)
        case .emailAlreadyInUse:
            state.bindings.alertInfo = AlertInfo(id: .emailAlreadyInUseAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.nativeRegistrationEmailInUse)
        case .invalidUsername:
            state.bindings.alertInfo = AlertInfo(id: .invalidUsernameAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.nativeRegistrationInvalidUsername)
        case .usernameInUse:
            state.bindings.alertInfo = AlertInfo(id: .usernameInUseAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.nativeRegistrationUsernameInUse)
        case .invalidRegistrationToken:
            state.bindings.alertInfo = AlertInfo(id: .invalidRegistrationTokenAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.nativeRegistrationInvalidRegistrationToken)
        default:
            state.bindings.alertInfo = AlertInfo(id: .unknown)
        }
    }
}
