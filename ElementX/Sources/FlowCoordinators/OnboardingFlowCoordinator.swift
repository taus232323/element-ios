//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import SwiftState

enum OnboardingFlowCoordinatorAction {
    case requestPresentation(animated: Bool)
    case dismiss
}

class OnboardingFlowCoordinator: FlowCoordinatorProtocol {
    private let appLockService: AppLockServiceProtocol
    private let analyticsService: AnalyticsService
    private let appSettings: AppSettings
    private let notificationManager: NotificationManagerProtocol
    private var isNewLogin: Bool
    
    private var navigationStackCoordinator: NavigationStackCoordinator!
    
    enum State: StateType {
        case initial
        case appLockSetup
        case analyticsPrompt
        case notificationPermissions
        case finished
    }
    
    enum Event: EventType {
        case next
    }
    
    private let stateMachine: StateMachine<State, Event>
    private var cancellables = Set<AnyCancellable>()
    
    // periphery: ignore - used to store the coordinator to avoid deallocation
    private var appLockFlowCoordinator: AppLockSetupFlowCoordinator?
    
    private let actionsSubject: PassthroughSubject<OnboardingFlowCoordinatorAction, Never> = .init()
    var actions: AnyPublisher<OnboardingFlowCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(isNewLogin: Bool,
         appLockService: AppLockServiceProtocol,
         navigationStackCoordinator: NavigationStackCoordinator,
         flowParameters: CommonFlowParameters) {
        self.isNewLogin = isNewLogin
        self.appLockService = appLockService
        analyticsService = flowParameters.analytics
        appSettings = flowParameters.appSettings
        notificationManager = flowParameters.notificationManager
        
        self.navigationStackCoordinator = navigationStackCoordinator
        
        stateMachine = .init(state: .initial)
        
        configureStateMachine()
    }
    
    var shouldStart: Bool {
        guard stateMachine.state == .initial, !ProcessInfo.isRunningIntegrationTests else {
            return false
        }
        
        return isNewLogin || requiresAppLockSetup || requiresAnalyticsSetup || requiresNotificationsSetup
    }
    
    func start(animated: Bool) {
        guard shouldStart else {
            fatalError("This flow coordinator shouldn't have been started")
        }
        
        actionsSubject.send(.requestPresentation(animated: !isNewLogin))

        stateMachine.tryEvent(.next)
    }
    
    func handleAppRoute(_ appRoute: AppRoute, animated: Bool) {
        fatalError()
    }
    
    func clearRoute(animated: Bool) {
        fatalError()
    }
    
    // MARK: - Private
    
    private var requiresAppLockSetup: Bool {
        appSettings.appLockIsMandatory && !appLockService.isEnabled
    }
    
    private var requiresAnalyticsSetup: Bool {
        analyticsService.shouldShowAnalyticsPrompt
    }
    
    private var requiresNotificationsSetup: Bool {
        !appSettings.hasRunNotificationPermissionsOnboarding
    }
    
    private func configureStateMachine() {
        stateMachine.addRoute(.init(fromState: .finished, toState: .initial))
        stateMachine.addRouteMapping { [weak self] _, fromState, _ in
            guard let self else {
                return nil
            }
            
            switch (fromState, requiresAppLockSetup, requiresAnalyticsSetup, requiresNotificationsSetup) {
            case (.initial, true, _, _):
                return .appLockSetup
            case (.initial, false, true, _):
                return .analyticsPrompt
            case (.initial, false, false, true):
                return .notificationPermissions
            case (.initial, false, false, false):
                return .finished
                
            case (.appLockSetup, _, true, _):
                return .analyticsPrompt
            case (.appLockSetup, _, false, true):
                return .notificationPermissions
            case (.appLockSetup, _, false, false):
                return .finished
                
            case (.analyticsPrompt, _, _, true):
                return .notificationPermissions
            case (.analyticsPrompt, _, _, false):
                return .finished
                
            case (.notificationPermissions, _, _, _):
                return .finished
            
            default:
                return nil
            }
        }
        
        stateMachine.addAnyHandler(.any => .any) { [weak self] context in
            guard let self else { return }
            
            switch (context.fromState, context.event, context.toState) {
            case (_, _, .appLockSetup):
                presentAppLockSetupFlow()
            case (_, _, .analyticsPrompt):
                presentAnalyticsPromptScreen()
            case (_, _, .notificationPermissions):
                presentNotificationPermissionsScreen()
            case (_, _, .finished):
                isNewLogin = false
                actionsSubject.send(.dismiss)
                stateMachine.tryState(.initial)
            case (.finished, _, .initial):
                break
            default:
                fatalError("Unknown transition: \(context)")
            }
            
            if let event = context.event {
                MXLog.info("Transitioning from `\(context.fromState)` to `\(context.toState)` with event `\(event)`")
            } else {
                MXLog.info("Transitioning from \(context.fromState)` to `\(context.toState)`")
            }
        }
        
        stateMachine.addErrorHandler { context in
            fatalError("Unexpected transition: \(context)")
        }
    }
    
    private func presentAppLockSetupFlow() {
        let coordinator = AppLockSetupFlowCoordinator(presentingFlow: .onboarding,
                                                      appLockService: appLockService,
                                                      navigationStackCoordinator: navigationStackCoordinator)
        coordinator.actions.sink { [weak self] action in
            guard let self else { return }
            switch action {
            case .complete:
                appLockFlowCoordinator = nil
                stateMachine.tryEvent(.next)
            case .forceLogout:
                fatalError("The PIN creation flow should not fail.")
            }
        }
        .store(in: &cancellables)
        
        appLockFlowCoordinator = coordinator
        coordinator.start()
    }

    private func presentAnalyticsPromptScreen() {
        let coordinator = AnalyticsPromptScreenCoordinator(analytics: analyticsService, termsURL: appSettings.analyticsTermsURL)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                switch action {
                case .done:
                    stateMachine.tryEvent(.next)
                }
            }
            .store(in: &cancellables)
        
        presentCoordinator(coordinator)
    }
    
    private func presentNotificationPermissionsScreen() {
        let coordinator = NotificationPermissionsScreenCoordinator(parameters: .init(notificationManager: notificationManager))
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                switch action {
                case .done:
                    appSettings.hasRunNotificationPermissionsOnboarding = true
                    stateMachine.tryEvent(.next)
                }
            }
            .store(in: &cancellables)
        
        presentCoordinator(coordinator)
    }
    
    private func presentCoordinator(_ coordinator: CoordinatorProtocol, dismissalCallback: (() -> Void)? = nil) {
        if navigationStackCoordinator.rootCoordinator == nil {
            navigationStackCoordinator.setRootCoordinator(coordinator, dismissalCallback: dismissalCallback)
        } else {
            navigationStackCoordinator.push(coordinator, dismissalCallback: dismissalCallback)
        }
    }
}
