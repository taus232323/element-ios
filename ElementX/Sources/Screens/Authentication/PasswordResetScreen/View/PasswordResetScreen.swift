//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct PasswordResetScreen: View {
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isVerificationCodeFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    @FocusState private var isConfirmPasswordFocused: Bool

    @Bindable var context: PasswordResetScreenViewModel.Context

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, UIConstants.titleTopPaddingToNavigationBar)
                .padding(.bottom, 32)

            form
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

    var header: some View {
        VStack(spacing: 8) {
            ArcanaMark(size: 208)
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
        case .email:
            ArcanaLocalization.passwordResetEmailStepTitle
        case .verificationCode:
            ArcanaLocalization.passwordResetCodeStepTitle
        case .credentials:
            ArcanaLocalization.passwordResetCredentialsStepTitle
        }
    }

    var subtitle: String {
        switch context.viewState.step {
        case .email:
            ArcanaLocalization.passwordResetEmailStepSubtitle(homeserver: context.viewState.homeserverAddress)
        case .verificationCode:
            ArcanaLocalization.passwordResetCodeStepSubtitle(email: context.viewState.bindings.email)
        case .credentials:
            ArcanaLocalization.passwordResetCredentialsStepSubtitle(homeserver: context.viewState.homeserverAddress)
        }
    }

    var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch context.viewState.step {
            case .email:
                Text(ArcanaLocalization.passwordResetEmailStepBody)
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .padding(.bottom, 16)

                TextField(text: $context.email) {
                    Text(ArcanaLocalization.nativeRegistrationEmailLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isEmailFocused)
                .textFieldStyle(.element(accessibilityIdentifier: "passwordResetEmail"))
                .disableAutocorrection(true)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .submitLabel(.done)
                .onSubmit(submit)
            case .verificationCode:
                Text(ArcanaLocalization.passwordResetCodeStepBody(email: context.viewState.bindings.email))
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textPrimary)
                    .padding(.bottom, 16)

                TextField(text: $context.verificationCode) {
                    Text(ArcanaLocalization.loginVerificationCodeLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isVerificationCodeFocused)
                .textFieldStyle(.element(accessibilityIdentifier: "passwordResetCode"))
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .submitLabel(.done)
                .onSubmit(submit)
                .onChange(of: context.verificationCode) { _, newValue in
                    let digitsOnly = newValue.filter(\.isNumber)
                    if digitsOnly != newValue {
                        context.verificationCode = digitsOnly
                    }
                }
                .padding(.bottom, 12)

                Text(ArcanaLocalization.passwordResetCodeStepHint)
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .padding(.bottom, 20)

                Button(action: { context.send(viewAction: .resendVerificationCode) }) {
                    Text(ArcanaLocalization.passwordResetResendEmail)
                }
                .buttonStyle(.compound(.textLink))
                .disabled(!context.viewState.canResendVerificationCode)
            case .credentials:
                Text(ArcanaLocalization.passwordResetCredentialsStepBody)
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .padding(.bottom, 16)

                SecureField(text: $context.password) {
                    Text(ArcanaLocalization.passwordResetNewPasswordLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isPasswordFocused)
                .textFieldStyle(.element(accessibilityIdentifier: "passwordResetPassword"))
                .textContentType(.newPassword)
                .submitLabel(.next)
                .onSubmit { isConfirmPasswordFocused = true }
                .padding(.bottom, 20)

                SecureField(text: $context.confirmPassword) {
                    Text(ArcanaLocalization.passwordResetConfirmPasswordLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isConfirmPasswordFocused)
                .textFieldStyle(.element(accessibilityIdentifier: "passwordResetConfirmPassword"))
                .textContentType(.newPassword)
                .submitLabel(.done)
                .onSubmit(submit)
            }

            Spacer().frame(height: 24)

            Button(action: submit) {
                Text(submitTitle)
            }
            .buttonStyle(.compound(.primary))
            .disabled(!context.viewState.canSubmit)
        }
    }

    var submitTitle: String {
        switch context.viewState.step {
        case .email:
            ArcanaLocalization.continueAction
        case .verificationCode:
            ArcanaLocalization.confirmAction
        case .credentials:
            ArcanaLocalization.passwordResetUpdatePassword
        }
    }

    private func submit() {
        guard context.viewState.canSubmit else { return }
        context.send(viewAction: .next)
        isEmailFocused = false
        isVerificationCodeFocused = false
        isPasswordFocused = false
        isConfirmPasswordFocused = false
    }
}

// MARK: - Previews

struct PasswordResetScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()

    static var previews: some View {
        ElementNavigationStack {
            PasswordResetScreen(context: viewModel.context)
        }
        .previewDisplayName("Initial State")
    }

    static func makeViewModel() -> PasswordResetScreenViewModel {
        PasswordResetScreenViewModel(authenticationService: AuthenticationService.mock,
                                     initialEmail: "alice@example.com",
                                     userIndicatorController: UserIndicatorControllerMock())
    }
}
