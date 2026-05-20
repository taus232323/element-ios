//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum NativeRegistrationScreenViewModelAction {
    case signedIn(UserSessionProtocol)
    case cancel
}

enum NativeRegistrationScreenStep: Equatable {
    case email
    case verificationCode
    case credentials
}

struct NativeRegistrationScreenViewState: BindableState {
    var isLoading = false
    var step: NativeRegistrationScreenStep = .email
    var pendingRegistration: PendingNativeRegistration?
    var bindings = NativeRegistrationScreenBindings()

    var hasValidCredentials: Bool {
        switch step {
        case .email:
            !bindings.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .verificationCode:
            !bindings.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .credentials:
            !bindings.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !bindings.password.isEmpty
        }
    }

    var canSubmit: Bool {
        hasValidCredentials && !isLoading
    }

    var canResendVerificationCode: Bool {
        pendingRegistration != nil && !isLoading
    }
}

struct NativeRegistrationScreenBindings {
    var email = ""
    var verificationCode = ""
    var username = ""
    var password = ""
    var alertInfo: AlertInfo<NativeRegistrationScreenErrorType>?
}

enum NativeRegistrationScreenViewAction {
    case next
    case back
    case resendVerificationCode
}

enum NativeRegistrationScreenErrorType: Hashable {
    case invalidVerificationCodeAlert
    case rateLimitedAlert(String)
    case invalidEmailAlert
    case emailAlreadyInUseAlert
    case invalidUsernameAlert
    case usernameInUseAlert
    case invalidRegistrationTokenAlert
    case unknown
}
