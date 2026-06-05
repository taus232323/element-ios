//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

protocol PasswordResetScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<PasswordResetScreenViewModelAction, Never> { get }
    var context: PasswordResetScreenViewModelType.Context { get }

    func stopLoading()
}
