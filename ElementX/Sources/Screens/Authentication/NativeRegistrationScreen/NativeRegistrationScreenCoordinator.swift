//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct NativeRegistrationScreenCoordinatorParameters {
    let authenticationService: AuthenticationServiceProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum NativeRegistrationScreenCoordinatorAction {
    case signedIn(UserSessionProtocol)
    case cancel
}

final class NativeRegistrationScreenCoordinator: CoordinatorProtocol {
    private let viewModel: NativeRegistrationScreenViewModelProtocol
    private let actionsSubject: PassthroughSubject<NativeRegistrationScreenCoordinatorAction, Never> = .init()
    private var cancellables = Set<AnyCancellable>()

    var actions: AnyPublisher<NativeRegistrationScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(parameters: NativeRegistrationScreenCoordinatorParameters) {
        viewModel = NativeRegistrationScreenViewModel(authenticationService: parameters.authenticationService,
                                                      userIndicatorController: parameters.userIndicatorController)
    }

    func start() {
        viewModel.actionsPublisher
            .sink { [weak self] action in
                guard let self else { return }

                switch action {
                case .signedIn(let userSession):
                    actionsSubject.send(.signedIn(userSession))
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
        AnyView(NativeRegistrationScreen(context: viewModel.context))
    }
}
