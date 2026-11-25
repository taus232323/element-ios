//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The screen shown at the beginning of the onboarding flow.
struct AuthenticationStartScreen: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @Bindable var context: AuthenticationStartScreenViewModel.Context
    
    var body: some View {
        standardContent
    }
    
    var standardContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: UIConstants.spacerHeight(in: geometry))
                
                content
                    .frame(width: geometry.size.width)
                    .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.hidden)
                
                Spacer()
                    .frame(height: 24)
                
                buttons
                    .frame(width: geometry.size.width)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 16)
                    .padding(.top, 8)
                
                Spacer()
                    .frame(height: UIConstants.spacerHeight(in: geometry))
            }
            .frame(minHeight: geometry.size.height)
        }
        .background {
            if context.viewState.mode != .addAccount {
                AuthenticationStartScreenBackgroundImage()
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(context.viewState.navigationTitle)
        .navigationBarHidden(context.viewState.navigationBarHidden)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
    }
    
    var content: some View {
        VStack(spacing: 0) {
            switch context.viewState.mode {
            case .addAccount:
                TitleAndIcon(title: L10n.screenOnboardingAddAccountTitle,
                             subtitle: L10n.screenOnboardingAddAccountSubtitle,
                             icon: \.plus,
                             iconStyle: .defaultSolid)
                    .padding(.top, 24)
                    .padding(.horizontal, 8)
            case .welcome:
                Spacer()
                
                ArcanaMark(size: 224)
                    .padding(.top, 8)
                
                Spacer()
                
                if !context.viewState.hideBrandChrome {
                    Text(ArcanaLocalization.onboardingWelcomeTitle)
                        .font(.compound.headingLGBold)
                        .foregroundColor(.compound.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            
            Spacer()
        }
        .padding(.bottom)
        .padding(.horizontal, 16)
        .readableFrame()
    }
    
    /// The main action buttons.
    var buttons: some View {
        VStack(spacing: 16) {
            Button { context.send(viewAction: .login) } label: {
                Text(context.viewState.loginButtonTitle)
            }
            .buttonStyle(.compound(.primary))
            .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.signIn)
            
            if context.viewState.showCreateAccountButton {
                Button { context.send(viewAction: .register) } label: {
                    Text(ArcanaLocalization.createAccount)
                }
                .buttonStyle(.compound(.tertiary))
            }
            
            Button { context.send(viewAction: .reportProblem) } label: {
                Text(ArcanaLocalization.reportProblem)
            }
            .buttonStyle(.compound(.textLink))
            .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.reportProblem)
            
            Text(context.viewState.legalNotice)
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
                .tint(.compound.textActionAccent)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            
            if context.viewState.mode != .addAccount {
                versionText
                    .font(.compound.bodySM)
                    .foregroundColor(.compound.textSecondary)
                    .onTapGesture(count: 7) {
                        context.send(viewAction: .reportProblem)
                    }
                    .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.appVersion)
                    .overlay(alignment: .trailing) {
                        developerOptionsButton
                            .scaledOffset(x: 32, y: -0.5, relativeTo: .compound.bodySM)
                    }
                    .padding(.top, 16)
            }
        }
        .padding(.horizontal, verticalSizeClass == .compact ? 128 : 24)
        .readableFrame()
    }
    
    var versionText: Text {
        // Let's not deal with snapshotting a changing version string.
        let shortVersionString = ProcessInfo.isRunningTests ? "0.0.0" : InfoPlistReader.main.bundleShortVersionString
        return Text(ArcanaLocalization.onboardingAppVersion(shortVersionString))
    }
    
    @ViewBuilder
    var developerOptionsButton: some View {
        if AppSettings.appBuildType != .release, !ProcessInfo.isRunningTests {
            Button { context.send(viewAction: .developerOptions) } label: {
                CompoundIcon(\.code)
                    .foregroundStyle(.compound.iconSecondary)
            }
            .accessibilityLabel(L10n.commonDeveloperOptions)
        }
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if context.viewState.mode == .addAccount {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancelAddingAccount)
                }
            }
        }
    }
}

// MARK: - Previews

struct AuthenticationStartScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let provisionedViewModel = makeViewModel(provisionedServerName: "example.com")
    static let addAccountViewModel = makeViewModel(isAddingAccount: true)
    
    static var previews: some View {
        AuthenticationStartScreen(context: viewModel.context)
            .previewDisplayName("Default")
        AuthenticationStartScreen(context: provisionedViewModel.context)
            .previewDisplayName("Provisioned")
        
        ElementNavigationStack {
            AuthenticationStartScreen(context: addAccountViewModel.context)
        }
        .previewDisplayName("Add Account")
    }
    
    static func makeViewModel(provisionedServerName: String? = nil, isAddingAccount: Bool = false) -> AuthenticationStartScreenViewModel {
        AuthenticationStartScreenViewModel(authenticationService: AuthenticationService.mock,
                                           provisioningParameters: provisionedServerName.map { .init(accountProvider: $0, loginHint: nil) },
                                           isAddingAccount: isAddingAccount,
                                           isBugReportServiceEnabled: true,
                                           appSettings: .volatile(),
                                           mediaProvider: MediaProviderMock(.init()),
                                           userIndicatorController: UserIndicatorControllerMock())
    }
}
