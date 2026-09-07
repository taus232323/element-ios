//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

enum AuthenticationStartScreenViewModelAction: Equatable {
    case login
    case register

    case loginDirectlyWithPassword(loginHint: String?)
    
    case reportProblem
    case developerOptions
}

struct AuthenticationStartScreenViewState: BindableState {
    let showCreateAccountButton: Bool
    
    let hideBrandChrome: Bool
    
    var bindings = AuthenticationStartScreenViewStateBindings()
    
    var loginButtonTitle: String {
        ArcanaLocalization.signIn
    }
}

struct AuthenticationStartScreenViewStateBindings {
    var alertInfo: AlertInfo<AuthenticationStartScreenAlertType>?
}

enum AuthenticationStartScreenAlertType {
    case genericError
}

enum AuthenticationStartScreenViewAction {
    case developerOptions
    case reportProblem
    
    case login
    case register
}
