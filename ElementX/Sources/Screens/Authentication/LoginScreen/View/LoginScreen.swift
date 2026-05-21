//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct LoginScreen: View {
    /// The focus state of the email text field.
    @FocusState private var isEmailFocused: Bool
    /// The focus state of the password text field.
    @FocusState private var isPasswordFocused: Bool
    /// The focus state of the verification code text field.
    @FocusState private var isVerificationCodeFocused: Bool

    @Bindable var context: LoginScreenViewModel.Context

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, UIConstants.titleTopPaddingToNavigationBar)
                .padding(.bottom, 32)

            switch context.viewState.loginMode {
            case .password:
                loginContent
            case .oidc:
                // This should never be shown.
                ProgressView()
            default:
                // This should never be shown either.
                loginUnavailableText
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .readableFrame()
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background {
            AuthenticationStartScreenBackgroundImage()
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    context.send(viewAction: .back)
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .alert(item: $context.alertInfo)
    }

    /// The header containing the title and icon.
    var header: some View {
        VStack(spacing: 8) {
            ArcanaMark(size: 240)
                .padding(.top, 8)
                .padding(.bottom, 8)
            
            Text(title)
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textPrimary)

            Text(subtitle)
                .font(.compound.bodyMD)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textSecondary)
        }
        .padding(.horizontal, 16)
    }

    var title: String {
        switch context.viewState.step {
        case .credentials:
            ArcanaLocalization.loginCredentialsTitle
        case .verificationCode:
            ArcanaLocalization.loginEmailVerificationTitle
        }
    }
    
    var subtitle: String {
        switch context.viewState.step {
        case .credentials:
            ArcanaLocalization.loginCredentialsSubtitle
        case .verificationCode:
            ArcanaLocalization.loginEmailVerificationSubtitle(email: context.viewState.bindings.email)
        }
    }

    /// The form with text fields for the current step, along with a submit button.
    var loginContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if context.viewState.step == .credentials {
                TextField(text: $context.email) {
                    Text(ArcanaLocalization.loginEmailLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isEmailFocused)
                .textFieldStyle(.element(accessibilityIdentifier: A11yIdentifiers.loginScreen.emailUsername))
                .disableAutocorrection(true)
                .textContentType(.username)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .submitLabel(.next)
                .onSubmit { isPasswordFocused = true }
                .padding(.bottom, 20)

                SecureField(text: $context.password) {
                    Text(ArcanaLocalization.passwordLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isPasswordFocused)
                .textFieldStyle(.element(accessibilityIdentifier: A11yIdentifiers.loginScreen.password))
                .textContentType(.password)
                .submitLabel(.done)
                .onSubmit(submit)
            } else {
                TextField(text: $context.verificationCode) {
                    Text(ArcanaLocalization.loginVerificationCodeLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isVerificationCodeFocused)
                .textFieldStyle(.element(accessibilityIdentifier: A11yIdentifiers.loginScreen.password))
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .submitLabel(.done)
                .onSubmit(submit)
                .onChange(of: context.verificationCode) { newValue in
                    let digitsOnly = newValue.filter(\.isNumber)
                    if digitsOnly != newValue {
                        context.verificationCode = digitsOnly
                    }
                }
                .padding(.bottom, 20)

                Button(action: { context.send(viewAction: .resendVerificationCode) }) {
                    Text(ArcanaLocalization.resendCode)
                }
                .buttonStyle(.compound(.textLink))
                .disabled(!context.viewState.canResendVerificationCode)
            }
            
            Spacer().frame(height: 24)

            Button(action: submit) {
                Text(context.viewState.step == .credentials ? ArcanaLocalization.continueAction : ArcanaLocalization.confirmAction)
            }
            .buttonStyle(.compound(.primary))
            .disabled(!context.viewState.canSubmit)
            .accessibilityIdentifier(A11yIdentifiers.loginScreen.continue)
        }
    }
    
    /// Text shown if neither password or OIDC login is supported.
    var loginUnavailableText: some View {
        Text(ArcanaLocalization.unsupportedAuthentication)
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.compound.textPrimary)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier(A11yIdentifiers.loginScreen.unsupportedServer)
    }
    
    /// Sends the `next` view action so long as valid credentials have been input.
    private func submit() {
        guard context.viewState.canSubmit else { return }
        context.send(viewAction: .next)
        isEmailFocused = false
        isPasswordFocused = false
        isVerificationCodeFocused = false
    }
}

// MARK: - Previews

struct LoginScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let credentialsViewModel = makeViewModel(withCredentials: true)
    static let unconfiguredViewModel = makeViewModel(homeserverAddress: "somethingtofailconfiguration")
    
    static var previews: some View {
        ElementNavigationStack {
            LoginScreen(context: viewModel.context)
        }
        .snapshotPreferences(expect: viewModel.context.observe(\.viewState.homeserver.loginMode).map { $0 == .password })
        .previewDisplayName("Initial State")
        
        ElementNavigationStack {
            LoginScreen(context: credentialsViewModel.context)
        }
        .snapshotPreferences(expect: credentialsViewModel.context.observe(\.viewState.homeserver.loginMode).map { $0 == .password })
        .previewDisplayName("Credentials Entered")
        
        ElementNavigationStack {
            LoginScreen(context: unconfiguredViewModel.context)
        }
        .previewDisplayName("Unsupported")
    }
    
    static func makeViewModel(homeserverAddress: String = "example.com", withCredentials: Bool = false) -> LoginScreenViewModel {
        let authenticationService = AuthenticationService.mock
        
        Task { await authenticationService.configure(for: homeserverAddress, flow: .login) }
        
        let viewModel = LoginScreenViewModel(authenticationService: authenticationService,
                                             loginHint: nil,
                                             userIndicatorController: UserIndicatorControllerMock(),
                                             appSettings: ServiceLocator.shared.settings)
        
        if withCredentials {
            viewModel.context.email = "alice@example.com"
            viewModel.context.password = "password"
        }
        
        return viewModel
    }
}
