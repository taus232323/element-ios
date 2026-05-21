//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias AuthenticationStartScreenViewModelType = StateStoreViewModelV2<AuthenticationStartScreenViewState, AuthenticationStartScreenViewAction>

class AuthenticationStartScreenViewModel: AuthenticationStartScreenViewModelType, AuthenticationStartScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let provisioningParameters: AccountProvisioningParameters?
    private let appMediator: AppMediatorProtocol
    private let appSettings: AppSettings
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let canReportProblem: Bool
    
    private var actionsSubject: PassthroughSubject<AuthenticationStartScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<AuthenticationStartScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(authenticationService: AuthenticationServiceProtocol,
         provisioningParameters: AccountProvisioningParameters?,
         isBugReportServiceEnabled: Bool,
         appMediator: AppMediatorProtocol,
         appSettings: AppSettings,
         mediaProvider: MediaProviderProtocol?,
         notificationCenter: NotificationCenter = .default,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.authenticationService = authenticationService
        self.provisioningParameters = provisioningParameters
        self.appMediator = appMediator
        self.appSettings = appSettings
        self.userIndicatorController = userIndicatorController
        canReportProblem = isBugReportServiceEnabled

        let classicAppAccountProvider = authenticationService.classicAppAccount?.serverName
        let isClassicAppAccountAllowed = classicAppAccountProvider.map { appSettings.accountProviders.contains($0) } ?? false
        
        let classicAppMode: AuthenticationStartScreenViewState.ClassicAppMode? = authenticationService.classicAppAccount.flatMap {
            isClassicAppAccountAllowed ? .welcomeBack($0) : nil
        }

        let initialViewState = AuthenticationStartScreenViewState(showCreateAccountButton: appSettings.showCreateAccountButton,
                                                                  classicAppMode: classicAppMode,
                                                                  hideBrandChrome: appSettings.hideBrandChrome)
        
        super.init(initialViewState: initialViewState, mediaProvider: mediaProvider)
        
        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.reloadClassicAppAccount()
            }
            .store(in: &cancellables)
    }
    
    override func process(viewAction: AuthenticationStartScreenViewAction) {
        switch viewAction {
        case .reportProblem:
            if canReportProblem {
                actionsSubject.send(.reportProblem)
            }
        case .developerOptions:
            actionsSubject.send(.developerOptions)
        case .login:
            Task { await login() }
        case .register:
            actionsSubject.send(.register)
        
        case .continueWithClassic(let account):
            Task { await login(classicAppAccount: account) }
        case .otherOptions(let account):
            state.classicAppMode = .otherOptions(account)
        case .closeOtherOptions(let account):
            state.classicAppMode = .welcomeBack(account)
        case .openClassicApp:
            guard let classicAppDeepLinkURL = InfoPlistReader.main.classicAppDeepLinkURL else { return }
            appMediator.open(classicAppDeepLinkURL)
        }
    }
    
    // MARK: - Private
    
    private func login(classicAppAccount: ClassicAppAccount? = nil) async {
        if let classicAppAccount {
            if classicAppAccount.state.availableSecrets == .requiresBackup {
                state.bindings.showClassicAppBackupInstructions = true
            } else {
                await configureAccountProvider(classicAppAccount.serverName,
                                               loginHint: nil,
                                               fallbackHomeserverURL: classicAppAccount.homeserverURL)
            }
        } else {
            actionsSubject.send(.loginDirectlyWithPassword(loginHint: provisioningParameters?.loginHint))
        }
    }

    private func configureAccountProvider(_ accountProvider: String, loginHint: String? = nil, fallbackHomeserverURL: URL? = nil) async {
        startLoading()
        defer { stopLoading() }
        
        if case .failure = await authenticationService.configure(for: accountProvider, flow: .login) {
            if let fallbackHomeserverURL,
               case .success = await authenticationService.configure(for: fallbackHomeserverURL.absoluteString, flow: .login) {
            } else {
                displayError()
                return
            }
        }
        actionsSubject.send(.loginDirectlyWithPassword(loginHint: loginHint))
    }
    
    @CancellableTask private var reloadClassicAppSecretsTask: Task<Void, Never>?
    private func reloadClassicAppAccount() {
        guard case let .welcomeBack(classicAppAccount) = state.classicAppMode else { return }
        
        reloadClassicAppSecretsTask = Task { [weak self] in
            await self?.authenticationService.refreshClassicAppAccountState()
            
            guard !Task.isCancelled else { return }
            
            if let availableSecrets = classicAppAccount.state.availableSecrets, availableSecrets != .requiresBackup {
                await MainActor.run { self?.state.bindings.showClassicAppBackupInstructions = false }
            }
        }
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(AuthenticationStartScreenViewModel.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID,
                                                              type: .modal,
                                                              title: ArcanaLocalization.loading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
    }
    
    private func displayError() {
        state.bindings.alertInfo = AlertInfo(id: .genericError)
    }
}
