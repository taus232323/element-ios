//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum LoginScreenViewModelAction {
    /// Login was successful.
    case signedIn(UserSessionProtocol)
}

struct LoginScreenViewState: BindableState {
    /// Data about the selected homeserver.
    var homeserver: LoginHomeserver
    /// Whether a new homeserver is currently being loaded.
    var isLoading = false
    /// View state that can be bound to from SwiftUI.
    var bindings = LoginScreenBindings()
    
    /// The types of login supported by the homeserver.
    var loginMode: LoginMode {
        homeserver.loginMode
    }
    
    /// `true` if the email and password are ready to be submitted.
    var hasValidCredentials: Bool {
        !bindings.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !bindings.password.isEmpty
    }
    
    /// `true` when valid credentials have been entered and a homeserver has been loaded.
    var canSubmit: Bool {
        hasValidCredentials && !isLoading
    }
}

struct LoginScreenBindings {
    /// The email input by the user.
    var email = ""
    /// The password input by the user.
    var password = ""
    /// Information describing the currently displayed alert.
    var alertInfo: AlertInfo<LoginScreenErrorType>?
}

enum LoginScreenViewAction {
    /// Continue using the input email and password.
    case next
}

enum LoginScreenErrorType: Hashable {
    /// A specific error message shown in an alert.
    case alert(String)
    /// An alert that informs the user to check their email/password.
    case credentialsAlert
    /// An alert that informs the user that their account has been deactivated.
    case deactivatedAlert
    /// An alert that informs the user about a bad well-known file.
    case invalidWellKnownAlert(String)
    /// An alert that allows the user to learn about sliding sync.
    case slidingSyncAlert
    /// An alert that informs the user that Element Pro should be used for a particular server.
    case elementProAlert
    /// An alert that informs the user that login failed due to a refresh token being returned.
    case refreshTokenAlert
    /// The response from the homeserver was unexpected.
    case unknown
}
