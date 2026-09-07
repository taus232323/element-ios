//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct ArcanaAppSettingsHook: AppSettingsHookProtocol {
    func configure(_ appSettings: AppSettings) -> AppSettings {
        let privacyURL = URL(string: "https://arcana.celesteai.ru/privacy")!
        let termsURL = URL(string: "https://arcana.celesteai.ru/terms")!
        // Same Sygnal host as Android (`FirebaseConfig.PUSHER_HTTP_URL`).
        let pushGatewayBaseURL = URL(string: "https://arcana.celesteai.ru")!
        appSettings.override(accountProviders: [InfoPlistReader.main.arcanaAccountProvider],
                             allowOtherAccountProviders: false,
                             hideBrandChrome: false,
                             pushGatewayBaseURL: pushGatewayBaseURL,
                             oidcRedirectURL: appSettings.oidcRedirectURL,
                             websiteURL: URL(string: "https://arcana.celesteai.ru")!,
                             logoURL: appSettings.logoURL,
                             copyrightURL: URL(string: "https://arcana.celesteai.ru/terms#copyright")!,
                             acceptableUseURL: termsURL,
                             privacyURL: privacyURL,
                             encryptionURL: appSettings.encryptionURL,
                             deviceVerificationURL: appSettings.deviceVerificationURL,
                             chatBackupDetailsURL: appSettings.chatBackupDetailsURL,
                             identityPinningViolationDetailsURL: appSettings.identityPinningViolationDetailsURL,
                             historySharingDetailsURL: appSettings.historySharingDetailsURL,
                             elementWebHosts: appSettings.elementWebHosts,
                             accountProvisioningHost: appSettings.accountProvisioningHost,
                             bugReportApplicationID: appSettings.bugReportApplicationID,
                             analyticsTermsURL: privacyURL,
                             mapTilerConfiguration: appSettings.mapTilerConfiguration)
        return appSettings
    }
}
