//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import SwiftUI

struct InviteScreenCoordinatorParameters {
    let token: String
    let webURL: URL
    let clientProxy: ClientProxyProtocol?
    let onOpenRoom: (String) -> Void
}

final class InviteScreenCoordinator: CoordinatorProtocol {
    private let parameters: InviteScreenCoordinatorParameters

    init(parameters: InviteScreenCoordinatorParameters) {
        self.parameters = parameters
    }

    func toPresentable() -> AnyView {
        AnyView(InviteScreen(token: parameters.token,
                             webURL: parameters.webURL,
                             clientProxy: parameters.clientProxy,
                             onOpenRoom: parameters.onOpenRoom))
    }
}
