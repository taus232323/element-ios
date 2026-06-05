//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum PasswordResetScreenViewModelAction {
    case complete
    case cancel
}

enum PasswordResetScreenStep: Equatable {
    case email
    case verificationCode
    case credentials
}

struct PasswordResetScreenViewState: BindableState {
    var homeserverAddress: String
    var isLoading = false
    var step: PasswordResetScreenStep = .email
    var pendingPasswordReset: PendingNativePasswordReset?
    var bindings: PasswordResetScreenBindings

    var hasValidCredentials: Bool {
        switch step {
        case .email:
            !bindings.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .verificationCode:
            !bindings.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .credentials:
            !bindings.password.isEmpty && !bindings.confirmPassword.isEmpty
        }
    }

    var canSubmit: Bool {
        hasValidCredentials && !isLoading
    }

    var canResendVerificationCode: Bool {
        pendingPasswordReset != nil && !isLoading
    }
}

struct PasswordResetScreenBindings {
    var email = ""
    var verificationCode = ""
    var password = ""
    var confirmPassword = ""
    var alertInfo: AlertInfo<PasswordResetScreenErrorType>?
}

enum PasswordResetScreenViewAction {
    case next
    case back
    case resendVerificationCode
}

enum PasswordResetScreenErrorType: Hashable {
    case passwordMismatchAlert
    case invalidVerificationCodeAlert
    case rateLimitedAlert(String)
    case invalidEmailAlert
    case successAlert
    case unknown
}
