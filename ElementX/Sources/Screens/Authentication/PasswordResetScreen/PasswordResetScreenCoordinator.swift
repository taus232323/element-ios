//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct PasswordResetScreenCoordinatorParameters {
    let authenticationService: AuthenticationServiceProtocol
    let initialEmail: String
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum PasswordResetScreenCoordinatorAction {
    case complete
    case cancel
}

final class PasswordResetScreenCoordinator: CoordinatorProtocol {
    private let viewModel: PasswordResetScreenViewModelProtocol
    private let actionsSubject: PassthroughSubject<PasswordResetScreenCoordinatorAction, Never> = .init()
    private var cancellables = Set<AnyCancellable>()

    var actions: AnyPublisher<PasswordResetScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(parameters: PasswordResetScreenCoordinatorParameters) {
        viewModel = PasswordResetScreenViewModel(authenticationService: parameters.authenticationService,
                                                 initialEmail: parameters.initialEmail,
                                                 userIndicatorController: parameters.userIndicatorController)
    }

    func start() {
        viewModel.actionsPublisher
            .sink { [weak self] action in
                guard let self else { return }

                switch action {
                case .complete:
                    actionsSubject.send(.complete)
                case .cancel:
                    actionsSubject.send(.cancel)
                }
            }
            .store(in: &cancellables)
    }

    func stop() {
        viewModel.stopLoading()
    }

    func toPresentable() -> AnyView {
        AnyView(PasswordResetScreen(context: viewModel.context))
    }
}
