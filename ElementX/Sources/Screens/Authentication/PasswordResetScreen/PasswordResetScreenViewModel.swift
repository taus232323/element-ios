//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias PasswordResetScreenViewModelType = StateStoreViewModelV2<PasswordResetScreenViewState, PasswordResetScreenViewAction>

final class PasswordResetScreenViewModel: PasswordResetScreenViewModelType, PasswordResetScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol

    private var actionsSubject: PassthroughSubject<PasswordResetScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<PasswordResetScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: AuthenticationServiceProtocol,
         initialEmail: String,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.authenticationService = authenticationService
        self.userIndicatorController = userIndicatorController

        let viewState = PasswordResetScreenViewState(homeserverAddress: authenticationService.homeserver.value.address,
                                                     bindings: PasswordResetScreenBindings(email: initialEmail))
        super.init(initialViewState: viewState)
    }

    override func process(viewAction: PasswordResetScreenViewAction) {
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
                switch await authenticationService.startNativePasswordReset(email: state.bindings.email) {
                case .success(let pendingPasswordReset):
                    state.pendingPasswordReset = pendingPasswordReset
                    state.step = .verificationCode
                    state.bindings.verificationCode = ""
                case .failure(let error):
                    handleError(error)
                }
                stopLoading()
            case .verificationCode:
                guard let pendingPasswordReset = state.pendingPasswordReset else {
                    stopLoading()
                    state.step = .email
                    return
                }
                switch await authenticationService.continueNativePasswordResetEmailCode(pendingPasswordReset,
                                                                                        verificationCode: state.bindings.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)) {
                case .success(let updatedPendingPasswordReset):
                    state.pendingPasswordReset = updatedPendingPasswordReset
                    state.step = .credentials
                    state.bindings.password = ""
                    state.bindings.confirmPassword = ""
                case .failure(let error):
                    handleError(error)
                }
                stopLoading()
            case .credentials:
                guard let pendingPasswordReset = state.pendingPasswordReset else {
                    stopLoading()
                    state.step = .email
                    return
                }
                guard state.bindings.password == state.bindings.confirmPassword else {
                    stopLoading()
                    state.bindings.alertInfo = AlertInfo(id: .passwordMismatchAlert,
                                                         title: ArcanaLocalization.errorTitle,
                                                         message: ArcanaLocalization.passwordResetPasswordMismatch)
                    return
                }
                switch await authenticationService.finishNativePasswordReset(pendingPasswordReset,
                                                                             password: state.bindings.password) {
                case .success:
                    state.pendingPasswordReset = nil
                    state.bindings.password = ""
                    state.bindings.confirmPassword = ""
                    state.bindings.alertInfo = AlertInfo(id: .successAlert,
                                                         title: ArcanaLocalization.passwordResetSuccessTitle,
                                                         message: ArcanaLocalization.passwordResetSuccessMessage,
                                                         primaryButton: .init(title: L10n.actionOk) { [weak self] in
                                                             self?.actionsSubject.send(.complete)
                                                         })
                case .failure(let error):
                    handleError(error)
                }
                stopLoading()
            }
        }
    }

    private func resendVerificationCode() {
        guard let pendingPasswordReset = state.pendingPasswordReset else { return }
        startLoading()
        Task {
            switch await authenticationService.resendNativePasswordResetEmail(pendingPasswordReset) {
            case .success(let updatedPendingPasswordReset):
                state.pendingPasswordReset = updatedPendingPasswordReset
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

    private static let loadingIndicatorIdentifier = "\(PasswordResetScreenViewModel.self)-Loading"

    private func startLoading() {
        state.isLoading = true
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal,
                                                              title: ArcanaLocalization.loading,
                                                              persistent: true))
    }

    private func handleError(_ error: AuthenticationServiceError) {
        MXLog.info("Password reset error occurred: \(error)")

        switch error {
        case .invalidVerificationCode:
            state.bindings.alertInfo = AlertInfo(id: .invalidVerificationCodeAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.passwordResetInvalidCode)
        case .rateLimited(let retryAfterMs):
            let seconds = retryAfterMs.map { max(1, $0 / 1000) } ?? 0
            state.bindings.alertInfo = AlertInfo(id: .rateLimitedAlert("\(seconds)"),
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.passwordResetRateLimited(seconds: seconds))
        case .invalidEmail:
            state.bindings.alertInfo = AlertInfo(id: .invalidEmailAlert,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.passwordResetInvalidEmail)
        default:
            state.bindings.alertInfo = AlertInfo(id: .unknown,
                                                 title: ArcanaLocalization.errorTitle,
                                                 message: ArcanaLocalization.passwordResetUnknownError)
        }
    }
}
