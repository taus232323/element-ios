//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct NativeRegistrationScreen: View {
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isVerificationCodeFocused: Bool
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isPasswordFocused: Bool

    @Bindable var context: NativeRegistrationScreenViewModel.Context

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
            ArcanaLocalization.nativeRegistrationEmailStepTitle
        case .verificationCode:
            ArcanaLocalization.nativeRegistrationCodeStepTitle
        case .credentials:
            ArcanaLocalization.nativeRegistrationCredentialsStepTitle
        }
    }

    var subtitle: String {
        switch context.viewState.step {
        case .email:
            ArcanaLocalization.nativeRegistrationEmailStepSubtitle
        case .verificationCode:
            ArcanaLocalization.nativeRegistrationCodeStepSubtitle(email: context.viewState.bindings.email)
        case .credentials:
            ArcanaLocalization.nativeRegistrationCredentialsStepSubtitle
        }
    }

    var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch context.viewState.step {
            case .email:
                TextField(text: $context.email) {
                    Text(ArcanaLocalization.nativeRegistrationEmailLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isEmailFocused)
                .textFieldStyle(.element(accessibilityIdentifier: "nativeRegistrationEmail"))
                .disableAutocorrection(true)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .submitLabel(.done)
                .onSubmit(submit)
            case .verificationCode:
                TextField(text: $context.verificationCode) {
                    Text(ArcanaLocalization.loginVerificationCodeLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isVerificationCodeFocused)
                .textFieldStyle(.element(accessibilityIdentifier: "nativeRegistrationCode"))
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
                .padding(.bottom, 20)

                Button(action: { context.send(viewAction: .resendVerificationCode) }, label: {
                    Text(ArcanaLocalization.nativeRegistrationResendEmail)
                })
                .buttonStyle(.compound(.textLink))
                .disabled(!context.viewState.canResendVerificationCode)
            case .credentials:
                TextField(text: $context.username) {
                    Text(ArcanaLocalization.nativeRegistrationUsernameLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isUsernameFocused)
                .textFieldStyle(.element(accessibilityIdentifier: "nativeRegistrationUsername"))
                .textContentType(.username)
                .autocapitalization(.none)
                .submitLabel(.next)
                .onSubmit { isPasswordFocused = true }
                .padding(.bottom, 20)

                SecureField(text: $context.password) {
                    Text(ArcanaLocalization.passwordLabel).foregroundColor(.compound.textSecondary)
                }
                .focused($isPasswordFocused)
                .textFieldStyle(.element(accessibilityIdentifier: "nativeRegistrationPassword"))
                .textContentType(.newPassword)
                .submitLabel(.done)
                .onSubmit(submit)
            }

            Spacer().frame(height: 24)

            Button(action: submit) {
                Text(context.viewState.step == .credentials ? ArcanaLocalization.nativeRegistrationCreateAccount : ArcanaLocalization.continueAction)
            }
            .buttonStyle(.compound(.primary))
            .disabled(!context.viewState.canSubmit)
        }
    }

    private func submit() {
        guard context.viewState.canSubmit else { return }
        context.send(viewAction: .next)
        isEmailFocused = false
        isVerificationCodeFocused = false
        isUsernameFocused = false
        isPasswordFocused = false
    }
}
