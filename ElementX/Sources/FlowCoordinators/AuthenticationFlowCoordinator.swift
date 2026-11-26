//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import SwiftState

enum AuthenticationFlowCoordinatorAction {
    case signInComplete(userSession: UserSessionProtocol)
    case cancelAddingAccount
}

class AuthenticationFlowCoordinator: FlowCoordinatorProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let isAddingAccount: Bool
    private let homeserverHistoryManager: HomeserverHistoryManager
    private let navigationStackCoordinator: NavigationStackCoordinator
    private let bugReportService: BugReportServiceProtocol
    private let appSettings: AppSettings
    private let appHooks: AppHooks
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    enum State: StateType {
        /// The state machine hasn't started.
        case initial
        
        /// The initial screen shown when you first launch the app.
        case startScreen
        
        /// The screen to login with a password.
        case loginScreen
        /// The screen to register a new account.
        case nativeRegistrationScreen
        
        /// The screen to report an error.
        case bugReportFlow
        /// The screen to toggle feature flags.
        case developerOptions
        
        /// The flow is complete.
        case complete
    }
    
    enum Event: EventType {
        /// The flow is being started.
        case start
        
        /// Modify the flow using the provisioning parameters in the `userInfo`.
        case applyProvisioningParameters
        
        /// Show the screen to login with password (with the optional login hint in the `userInfo`).
        case continueWithPassword
        /// Show the screen to register a new account.
        case continueWithNativeRegistration
        /// The password login was aborted.
        case cancelledPasswordLogin(previousState: State)
        /// The native registration flow was aborted.
        case cancelledNativeRegistration(previousState: State)
        
        /// The user encountered a problem.
        case reportProblem
        /// The user has finished reporting a problem (or viewing the logs).
        case bugReportFlowComplete
        
        /// The user wants to toggle a feature flag.
        case developerOptions
        /// The user finished toggling feature flags.
        case dismissedDeveloperOptions
        
        /// The user has successfully signed in. The new session can be found in the `userInfo`.
        case signedIn
        /// The user cancelled adding another account.
        case cancelledAddingAccount
    }
    
    private let stateMachine: StateMachine<State, Event>
    private var cancellables = Set<AnyCancellable>()
    
    // periphery:ignore - retaining purpose
    private var bugReportFlowCoordinator: BugReportFlowCoordinator?
    
    private let actionsSubject: PassthroughSubject<AuthenticationFlowCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<AuthenticationFlowCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(authenticationService: AuthenticationServiceProtocol,
         isAddingAccount: Bool = false,
         navigationStackCoordinator: NavigationStackCoordinator,
         bugReportService: BugReportServiceProtocol,
         appMediator: AppMediatorProtocol,
         appSettings: AppSettings,
         appHooks: AppHooks,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.authenticationService = authenticationService
        self.isAddingAccount = isAddingAccount
        homeserverHistoryManager = HomeserverHistoryManager(appSettings: appSettings)
        self.navigationStackCoordinator = navigationStackCoordinator
        self.bugReportService = bugReportService
        self.appSettings = appSettings
        // Retained in the signature for callers. QR login and Classic app deep links, which used it, are not part of Arcana.
        _ = appMediator
        self.appHooks = appHooks
        self.userIndicatorController = userIndicatorController
        
        stateMachine = .init(state: .initial)
        configureStateMachine()
    }
    
    func start(animated: Bool) {
        stateMachine.tryEvent(.start)
    }
    
    func handleAppRoute(_ appRoute: AppRoute, animated: Bool) {
        MXLog.info("Handling app route: \(appRoute)")
        
        switch appRoute {
        case .accountProvisioningLink(let provisioningParameters):
            guard appSettings.allowOtherAccountProviders else {
                MXLog.error("Provisioning links not allowed, ignoring.")
                return
            }
            
            if stateMachine.state != .startScreen {
                clearRoute(animated: animated)
            }
            
            stateMachine.tryEvent(.applyProvisioningParameters, userInfo: provisioningParameters)
        case .invite:
            // Invite links are applied after sign-in. There is no session to open them against here.
            MXLog.info("Ignoring invite route during authentication.")
        default:
            fatalError()
        }
    }
    
    func clearRoute(animated: Bool) {
        switch stateMachine.state {
        case .initial, .startScreen:
            break
        case .loginScreen:
            navigationStackCoordinator.popToRoot(animated: animated)
        case .nativeRegistrationScreen:
            navigationStackCoordinator.popToRoot(animated: animated)
        case .bugReportFlow:
            navigationStackCoordinator.setSheetCoordinator(nil)
        case .developerOptions:
            navigationStackCoordinator.setSheetCoordinator(nil)
        case .complete:
            fatalError()
        }
    }
    
    func handleOAuthCallbackURL(_ url: URL) {
        // Arcana signs in with email and a verification code, so there is no OAuth session to complete.
        MXLog.error("Ignoring OAuth callback during authentication: \(url)")
    }
    
    // MARK: - Setup
    
    private func configureStateMachine() {
        stateMachine.addRoutes(event: .start, transitions: [.initial => .startScreen]) { [weak self] _ in
            self?.showStartScreen(fromState: .initial)
        }
        
        stateMachine.addRoutes(event: .applyProvisioningParameters, transitions: [.initial => .startScreen,
                                                                                  .startScreen => .startScreen]) { [weak self] context in
            guard let provisioningParameters = context.userInfo as? AccountProvisioningParameters else { fatalError("The authentication configuration is missing.") }
            self?.showStartScreen(fromState: context.fromState, applying: provisioningParameters)
        }
        
        // Manual Authentication
        
        stateMachine.addRoutes(event: .continueWithPassword, transitions: [.startScreen => .loginScreen]) { [weak self] context in
            let loginHint = context.userInfo as? String
            self?.showLoginScreen(loginHint: loginHint, fromState: .startScreen)
        }
        // Pop can dismiss synchronously and then the explicit event runs, or the other way around.
        // Both routes keep the state machine aligned without a double transition.
        stateMachine.addRoutes(event: .cancelledPasswordLogin(previousState: .startScreen), transitions: [.startScreen => .startScreen])
        stateMachine.addRoutes(event: .cancelledPasswordLogin(previousState: .startScreen), transitions: [.loginScreen => .startScreen])
        stateMachine.addRoutes(event: .continueWithNativeRegistration, transitions: [.startScreen => .nativeRegistrationScreen]) { [weak self] _ in
            self?.showNativeRegistrationScreen(fromState: .startScreen)
        }
        stateMachine.addRoutes(event: .cancelledNativeRegistration(previousState: .startScreen), transitions: [.startScreen => .startScreen])
        stateMachine.addRoutes(event: .cancelledNativeRegistration(previousState: .startScreen), transitions: [.nativeRegistrationScreen => .startScreen])
        
        // Bug Report
        
        stateMachine.addRoutes(event: .reportProblem, transitions: [.startScreen => .bugReportFlow]) { [weak self] _ in
            self?.startBugReportFlow()
        }
        stateMachine.addRoutes(event: .bugReportFlowComplete, transitions: [.bugReportFlow => .startScreen])
        
        // Developer Options
        
        stateMachine.addRoutes(event: .developerOptions, transitions: [.startScreen => .developerOptions]) { [weak self] _ in
            self?.showDeveloperOptionsScreen()
        }
        stateMachine.addRoutes(event: .dismissedDeveloperOptions, transitions: [.developerOptions => .startScreen])
        
        // Completion
        
        stateMachine.addRoutes(event: .signedIn, transitions: [.loginScreen => .complete,
                                                               .nativeRegistrationScreen => .complete]) { [weak self] context in
            guard let userSession = context.userInfo as? UserSessionProtocol else { fatalError("The user session wasn't included in the context") }
            self?.userHasSignedIn(userSession: userSession)
        }
        
        stateMachine.addRoutes(event: .cancelledAddingAccount, transitions: [.startScreen => .complete]) { [weak self] _ in
            self?.actionsSubject.send(.cancelAddingAccount)
        }
        
        // Logging
        
        stateMachine.addAnyHandler(.any => .any) { context in
            MXLog.info("Transitioning from `\(context.fromState)` to `\(context.toState)` with event `\(String(describing: context.event))`.")
        }
        
        // Unhandled
        
        stateMachine.addErrorHandler { context in
            switch (context.fromState, context.toState) {
            case (.complete, .complete):
                break // Ignore all events triggered by
            default:
                fatalError("Unexpected transition: \(context)")
            }
        }
    }
    
    private func showStartScreen(fromState: State, applying provisioningParameters: AccountProvisioningParameters? = nil) {
        _ = fromState
        let parameters = AuthenticationStartScreenParameters(authenticationService: authenticationService,
                                                             provisioningParameters: provisioningParameters,
                                                             isAddingAccount: isAddingAccount,
                                                             isBugReportServiceEnabled: appSettings.bundledBugReportRageshakeConfiguration.isEnabled,
                                                             appSettings: appSettings,
                                                             mediaProvider: nil,
                                                             userIndicatorController: userIndicatorController)
        let coordinator = AuthenticationStartScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .login:
                    stateMachine.tryEvent(.continueWithPassword)
                case .register:
                    stateMachine.tryEvent(.continueWithNativeRegistration)
                case .loginDirectlyWithPassword(let loginHint):
                    stateMachine.tryEvent(.continueWithPassword, userInfo: loginHint)
                    
                case .cancelAddingAccount:
                    stateMachine.tryEvent(.cancelledAddingAccount)
                    
                case .reportProblem:
                    stateMachine.tryEvent(.reportProblem)
                case .developerOptions:
                    stateMachine.tryEvent(.developerOptions)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.setRootCoordinator(coordinator)
    }
    
    // MARK: - Manual Authentication
    
    private func showLoginScreen(loginHint: String?, fromState: State) {
        let parameters = LoginScreenCoordinatorParameters(authenticationService: authenticationService,
                                                          loginHint: loginHint,
                                                          userIndicatorController: userIndicatorController)
        let coordinator = LoginScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .signedIn(let userSession):
                    stateMachine.tryEvent(.signedIn, userInfo: userSession)
                case .cancel:
                    // Pop first so the UI returns immediately; dismissal callback (or this event)
                    // keeps the state machine in sync. Guard in handlePasswordLoginDismissal
                    // prevents a double transition if both paths run.
                    navigationStackCoordinator.pop()
                    stateMachine.tryEvent(.cancelledPasswordLogin(previousState: fromState))
                case .forgotPassword(let initialEmail):
                    showPasswordResetScreen(initialEmail: initialEmail)
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator) { [weak self] in
            self?.handlePasswordLoginDismissal(previousState: fromState)
        }
    }
    
    private func showPasswordResetScreen(initialEmail: String) {
        let parameters = PasswordResetScreenCoordinatorParameters(authenticationService: authenticationService,
                                                                  initialEmail: initialEmail,
                                                                  userIndicatorController: userIndicatorController)
        let coordinator = PasswordResetScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .complete, .cancel:
                    navigationStackCoordinator.pop()
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator)
    }
    
    private func showNativeRegistrationScreen(fromState: State) {
        let parameters = NativeRegistrationScreenCoordinatorParameters(authenticationService: authenticationService,
                                                                       userIndicatorController: userIndicatorController)
        let coordinator = NativeRegistrationScreenCoordinator(parameters: parameters)
        
        coordinator.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .signedIn(let userSession):
                    stateMachine.tryEvent(.signedIn, userInfo: userSession)
                case .cancel:
                    navigationStackCoordinator.pop()
                    stateMachine.tryEvent(.cancelledNativeRegistration(previousState: fromState))
                }
            }
            .store(in: &cancellables)
        
        navigationStackCoordinator.push(coordinator) { [weak self] in
            self?.handleNativeRegistrationDismissal(previousState: fromState)
        }
    }
    
    // MARK: - Bug Report
    
    private func startBugReportFlow() {
        let coordinator = BugReportFlowCoordinator(parameters: .init(flow: .authentication(appSettings),
                                                                     presentationMode: .sheet(navigationStackCoordinator),
                                                                     bugReportService: bugReportService,
                                                                     bugReportHook: appHooks.bugReportHook,
                                                                     userIndicatorController: userIndicatorController))
        coordinator.actionsPublisher.sink { [weak self] action in
            switch action {
            case .complete:
                self?.stateMachine.tryEvent(.bugReportFlowComplete)
            }
        }
        .store(in: &cancellables)
        
        bugReportFlowCoordinator = coordinator
        coordinator.start()
    }
    
    // MARK: - Developer Options
    
    private func showDeveloperOptionsScreen() {
        let stackCoordinator = NavigationStackCoordinator()
        let coordinator = DeveloperOptionsScreenCoordinator(appSettings: appSettings,
                                                            screenHook: appHooks.developerOptionsScreenHook,
                                                            clientProxy: nil)
        coordinator.actions
            .sink { action in
                switch action {
                case .clearCache:
                    break // Not sent when clientProxy == nil
                }
            }
            .store(in: &cancellables)
        
        stackCoordinator.setRootCoordinator(coordinator)
        navigationStackCoordinator.setSheetCoordinator(stackCoordinator) { [weak self] in
            self?.stateMachine.tryEvent(.dismissedDeveloperOptions)
        }
    }
    
    // MARK: - Completion
    
    private func userHasSignedIn(userSession: UserSessionProtocol) {
        actionsSubject.send(.signInComplete(userSession: userSession))
        
        let newAccountProvider = authenticationService.homeserver.value.accountProvider
        homeserverHistoryManager.addServerToList(newAccountProvider.serverNameOrBaseURL)
    }
    
    // MARK: - Dismissal Handling
    
    private func handlePasswordLoginDismissal(previousState: State) {
        guard stateMachine.state == .loginScreen else { return }
        stateMachine.tryEvent(.cancelledPasswordLogin(previousState: previousState))
    }
    
    private func handleNativeRegistrationDismissal(previousState: State) {
        guard stateMachine.state == .nativeRegistrationScreen else { return }
        stateMachine.tryEvent(.cancelledNativeRegistration(previousState: previousState))
    }
}
