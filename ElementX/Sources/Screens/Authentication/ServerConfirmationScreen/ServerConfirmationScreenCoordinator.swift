//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct ServerConfirmationScreenCoordinatorParameters {
    let authenticationService: AuthenticationServiceProtocol
    let authenticationFlow: AuthenticationFlow
    let appSettings: AppSettings
    let userIndicatorController: UserIndicatorControllerProtocol
}

enum ServerConfirmationScreenCoordinatorAction {
    case continueWithPassword
}

final class ServerConfirmationScreenCoordinator: CoordinatorProtocol {
    private var viewModel: ServerConfirmationScreenViewModelProtocol
    private let actionsSubject: PassthroughSubject<ServerConfirmationScreenCoordinatorAction, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    
    var actions: AnyPublisher<ServerConfirmationScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: ServerConfirmationScreenCoordinatorParameters) {
        viewModel = ServerConfirmationScreenViewModel(authenticationService: parameters.authenticationService,
                                                      mode: .confirmation(parameters.authenticationService.homeserver.value.address),
                                                      authenticationFlow: parameters.authenticationFlow,
                                                      appSettings: parameters.appSettings,
                                                      userIndicatorController: parameters.userIndicatorController)
    }
    
    func start() {
        viewModel.actions.sink { [weak self] action in
            guard let self else { return }
            
            switch action {
            case .continueWithPassword:
                actionsSubject.send(.continueWithPassword)
            }
        }
        .store(in: &cancellables)
    }
        
    func toPresentable() -> AnyView {
        AnyView(ServerConfirmationScreen(context: viewModel.context))
    }
}
