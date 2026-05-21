//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum ArcanaLocalization {
    private static var isRussian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ru") == true
    }

    static var onboardingWelcomeTitle: String {
        isRussian ? "Добро пожаловать в Arcana" : UntranslatedL10n.screenOnboardingWelcomeTitleIos
    }

    static var loginCredentialsTitle: String {
        isRussian ? "Вход" : UntranslatedL10n.screenLoginCredentialsTitleIos
    }

    static var loginCredentialsSubtitle: String {
        isRussian ? "Введите логин или электронную почту и пароль." : UntranslatedL10n.screenLoginCredentialsSubtitleIos
    }

    static var loginEmailLabel: String {
        isRussian ? "Логин или электронная почта" : UntranslatedL10n.screenLoginEmail
    }

    static var loginEmailVerificationTitle: String {
        isRussian ? "Подтвердите email" : UntranslatedL10n.screenLoginEmailVerificationTitleIos
    }

    static func loginEmailVerificationSubtitle(email: String) -> String {
        if isRussian {
            return "Мы отправили код на \(email). Введите его ниже, чтобы продолжить."
        } else {
            return UntranslatedL10n.screenLoginEmailVerificationSubtitleIos(email)
        }
    }

    static var loginVerificationCodeLabel: String {
        isRussian ? "Код подтверждения" : UntranslatedL10n.screenLoginVerificationCodeLabelIos
    }

    static var loginInvalidCredentials: String {
        isRussian ? "Неверные email и/или пароль." : UntranslatedL10n.screenLoginErrorInvalidCredentials
    }

    static var loginInvalidVerificationCode: String {
        isRussian ? "Неверный код подтверждения." : UntranslatedL10n.screenLoginErrorInvalidVerificationCodeIos
    }

    static func loginRateLimited(seconds: Int) -> String {
        if isRussian {
            return "Подождите \(seconds) секунд перед запросом нового кода."
        } else {
            return UntranslatedL10n.screenLoginErrorRateLimitedIos(seconds)
        }
    }

    static var loginEmailVerificationUnavailable: String {
        isRussian ? "Для этого аккаунта подтверждение по email недоступно." : UntranslatedL10n.screenLoginErrorEmailVerificationUnavailableIos
    }

    static var loginInvalidEmail: String {
        isRussian ? "Введите корректный адрес почты." : UntranslatedL10n.screenLoginErrorInvalidEmailIos
    }

    static var loginEmailAlreadyInUse: String {
        isRussian ? "Этот адрес почты уже используется." : UntranslatedL10n.screenLoginErrorEmailAlreadyInUseIos
    }

    static var loginInvalidUsername: String {
        isRussian ? "Этот username недействителен." : UntranslatedL10n.screenLoginErrorInvalidUsernameIos
    }

    static var loginUsernameInUse: String {
        isRussian ? "Этот username уже занят." : UntranslatedL10n.screenLoginErrorUsernameInUseIos
    }

    static var loginInvalidRegistrationToken: String {
        isRussian ? "Неверный токен регистрации." : UntranslatedL10n.screenLoginErrorInvalidRegistrationTokenIos
    }

    static var resendCode: String {
        isRussian ? "Отправить код снова" : UntranslatedL10n.actionResendCodeIos
    }

    static var signIn: String {
        isRussian ? "Войти" : UntranslatedL10n.actionSignInIos
    }

    static var continueAction: String {
        isRussian ? "Продолжить" : L10n.actionContinue
    }

    static var confirmAction: String {
        isRussian ? "Подтвердить" : L10n.actionConfirm
    }

    static var createAccount: String {
        isRussian ? "Создать аккаунт" : L10n.screenCreateAccountTitle
    }

    static var reportProblem: String {
        isRussian ? "Сообщить о проблеме" : L10n.commonReportAProblem
    }

    static var otherOptions: String {
        isRussian ? "Другие варианты" : L10n.commonOtherOptions
    }

    static var welcomeBack: String {
        isRussian ? "Снова рады видеть" : L10n.screenOnboardingWelcomeBack
    }

    static var checkingAccount: String {
        isRussian ? "Проверяем аккаунт" : L10n.screenOnboardingCheckingAccount
    }

    static func onboardingAppVersion(_ version: String) -> String {
        if isRussian {
            return "Версия \(version)"
        } else {
            return L10n.screenOnboardingAppVersion(version)
        }
    }

    static var passwordLabel: String {
        isRussian ? "Пароль" : L10n.commonPassword
    }

    static var loading: String {
        isRussian ? "Загрузка" : L10n.commonLoading
    }

    static var errorTitle: String {
        isRussian ? "Ошибка" : L10n.commonError
    }

    static var cancelAction: String {
        isRussian ? "Отмена" : L10n.actionCancel
    }

    static var serverNotSupported: String {
        isRussian ? "Сервер не поддерживается" : L10n.commonServerNotSupported
    }

    static var unsupportedAuthentication: String {
        isRussian ? "Этот способ входа не поддерживается." : L10n.screenLoginErrorUnsupportedAuthentication
    }

    static var nativeRegistrationTitle: String {
        isRussian ? "Создание аккаунта" : UntranslatedL10n.screenNativeRegistrationTitleIos
    }

    static var nativeRegistrationEmailStepTitle: String {
        isRussian ? "Создайте аккаунт" : UntranslatedL10n.screenNativeRegistrationEmailStepTitleIos
    }

    static var nativeRegistrationEmailStepSubtitle: String {
        isRussian ? "Введите адрес почты, чтобы получить код подтверждения." : UntranslatedL10n.screenNativeRegistrationEmailStepSubtitleIos
    }

    static var nativeRegistrationEmailLabel: String {
        isRussian ? "Email" : UntranslatedL10n.screenNativeRegistrationEmailLabelIos
    }

    static var nativeRegistrationCodeStepTitle: String {
        isRussian ? "Подтвердите email" : UntranslatedL10n.screenNativeRegistrationCodeStepTitleIos
    }

    static func nativeRegistrationCodeStepSubtitle(email: String) -> String {
        if isRussian {
            return "Мы отправили код на \(email). Введите его ниже."
        } else {
            return UntranslatedL10n.screenNativeRegistrationCodeStepSubtitleIos(email)
        }
    }

    static func nativeRegistrationCodeStepBody(email: String) -> String {
        if isRussian {
            return "Введите код подтверждения, отправленный на \(email)."
        } else {
            return UntranslatedL10n.screenNativeRegistrationCodeStepBodyIos(email)
        }
    }

    static var nativeRegistrationResendEmail: String {
        isRussian ? "Отправить письмо снова" : UntranslatedL10n.screenNativeRegistrationActionResendEmailIos
    }

    static var nativeRegistrationCredentialsStepTitle: String {
        isRussian ? "Выберите имя пользователя и пароль" : UntranslatedL10n.screenNativeRegistrationCredentialsStepTitleIos
    }

    static var nativeRegistrationCredentialsStepSubtitle: String {
        isRussian ? "Это будет имя вашей учётной записи Arcana." : UntranslatedL10n.screenNativeRegistrationCredentialsStepSubtitleIos
    }

    static var nativeRegistrationUsernameLabel: String {
        isRussian ? "Имя пользователя" : UntranslatedL10n.screenNativeRegistrationUsernameLabelIos
    }

    static var nativeRegistrationCreateAccount: String {
        isRussian ? "Создать аккаунт" : UntranslatedL10n.screenNativeRegistrationActionCreateAccountIos
    }

    static var nativeRegistrationInvalidCode: String {
        isRussian ? "Неверный код подтверждения." : UntranslatedL10n.screenNativeRegistrationErrorInvalidCodeIos
    }

    static func nativeRegistrationRateLimited(seconds: Int) -> String {
        if isRussian {
            return "Подождите \(seconds) секунд перед запросом нового кода."
        } else {
            return UntranslatedL10n.screenNativeRegistrationErrorRateLimitedIos(seconds)
        }
    }

    static var nativeRegistrationInvalidEmail: String {
        isRussian ? "Введите корректный адрес почты." : UntranslatedL10n.screenNativeRegistrationErrorInvalidEmailIos
    }

    static var nativeRegistrationEmailInUse: String {
        isRussian ? "Этот адрес почты уже используется." : UntranslatedL10n.screenNativeRegistrationErrorEmailInUseIos
    }

    static var nativeRegistrationInvalidUsername: String {
        isRussian ? "Этот username недействителен." : UntranslatedL10n.screenNativeRegistrationErrorInvalidUsernameIos
    }

    static var nativeRegistrationUsernameInUse: String {
        isRussian ? "Этот username уже занят." : UntranslatedL10n.screenNativeRegistrationErrorUsernameInUseIos
    }

    static var nativeRegistrationInvalidRegistrationToken: String {
        isRussian ? "Неверный токен регистрации." : UntranslatedL10n.screenNativeRegistrationErrorInvalidRegistrationTokenIos
    }
}
