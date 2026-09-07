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
            AuthenticationStartScreenBackgroundImage()
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .alert(item: $context.alertInfo)
    }
    
    var content: some View {
        VStack(spacing: 0) {
            Spacer()
            
            if verticalSizeClass == .regular {
                Spacer()
                
                ArcanaMark(size: 224)
                    .padding(.top, 8)
            }
            
            Spacer()
            
            if !context.viewState.hideBrandChrome {
                VStack(spacing: 8) {
                    Text(ArcanaLocalization.onboardingWelcomeTitle)
                        .font(.compound.headingLGBold)
                        .foregroundColor(.compound.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .fixedSize(horizontal: false, vertical: true)
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
            
            versionText
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
                .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.appVersion)
                .padding(.top, 16)
        }
        .padding(.horizontal, verticalSizeClass == .compact ? 128 : 24)
        .readableFrame()
    }
    
    var versionText: Text {
        // Let's not deal with snapshotting a changing version string.
        let shortVersionString = ProcessInfo.isRunningTests ? "0.0.0" : InfoPlistReader.main.bundleShortVersionString
        return Text(ArcanaLocalization.onboardingAppVersion(shortVersionString))
    }
}

// MARK: - Previews

struct AuthenticationStartScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let provisionedViewModel = makeViewModel(provisionedServerName: "example.com")
    
    static var previews: some View {
        AuthenticationStartScreen(context: viewModel.context)
            .previewDisplayName("Default")
        AuthenticationStartScreen(context: provisionedViewModel.context)
            .previewDisplayName("Provisioned")
    }
    
    static func makeViewModel(provisionedServerName: String? = nil) -> AuthenticationStartScreenViewModel {
        AuthenticationStartScreenViewModel(authenticationService: AuthenticationService.mock,
                                           provisioningParameters: provisionedServerName.map { .init(accountProvider: $0, loginHint: nil) },
                                           isBugReportServiceEnabled: true,
                                           appSettings: ServiceLocator.shared.settings,
                                           mediaProvider: MediaProviderMock(configuration: .init()),
                                           userIndicatorController: UserIndicatorControllerMock())
    }
}
