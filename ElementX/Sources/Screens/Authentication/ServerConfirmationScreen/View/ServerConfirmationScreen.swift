//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ServerConfirmationScreen: View {
    @Bindable var context: ServerConfirmationScreenViewModel.Context
    
    private var backgroundColor: Color {
        .compound.bgCanvasDefault
    }
    
    private var headerIcon: KeyPath<CompoundIcons, Image> {
        \.userProfileSolid
    }
    
    private var headerIconStyle: BigIcon.Style {
        .defaultSolid
    }
    
    var body: some View {
        FullscreenDialog(topPadding: UIConstants.iconTopPaddingToNavigationBar) {
            VStack(spacing: 36) {
                header
                mainContent
            }
        } bottomContent: {
            buttons
        }
        .background()
        .backgroundStyle(backgroundColor)
        .alert(item: $context.alertInfo)
    }
    
    /// The main content of the view to be shown in a scroll view.
    var header: some View {
        VStack(spacing: 8) {
            BigIcon(icon: headerIcon, style: headerIconStyle)
                .padding(.bottom, 8)
            
            Text(context.viewState.title)
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let message = context.viewState.message {
                Text(message)
                    .font(.compound.bodyMD)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.compound.textSecondary)
            }
        }
        .padding(.horizontal, 16)
    }
    
    var mainContent: some View {
        EmptyView()
    }
    
    /// The action buttons shown at the bottom of the view.
    var buttons: some View {
        VStack(spacing: 16) {
            Button { context.send(viewAction: .confirm) } label: {
                Text(ArcanaLocalization.continueAction)
            }
            .buttonStyle(.compound(.primary))
            .accessibilityIdentifier(A11yIdentifiers.serverConfirmationScreen.continue)
        }
    }
}

// MARK: - Previews

struct ServerConfirmationScreen_Previews: PreviewProvider, TestablePreview {
    static let loginViewModel = makeViewModel(mode: .confirmation("matrix.org"), flow: .login)
    static let registerViewModel = makeViewModel(mode: .confirmation("matrix.org"), flow: .register)
    static var previews: some View {
        ElementNavigationStack {
            ServerConfirmationScreen(context: loginViewModel.context)
                .toolbar(.visible, for: .navigationBar)
        }
        .previewDisplayName("Login")
        
        ElementNavigationStack {
            ServerConfirmationScreen(context: registerViewModel.context)
                .toolbar(.visible, for: .navigationBar)
        }
        .previewDisplayName("Register")
    }
    
    static func makeViewModel(mode: ServerConfirmationScreenMode, flow: AuthenticationFlow) -> ServerConfirmationScreenViewModel {
        ServerConfirmationScreenViewModel(authenticationService: AuthenticationService.mock,
                                          mode: mode,
                                          authenticationFlow: flow,
                                          appSettings: ServiceLocator.shared.settings,
                                          userIndicatorController: UserIndicatorControllerMock())
    }
}
