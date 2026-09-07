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
        let baseURL = URL(string: "https://arcana.celesteai.ru")!
        let privacyURL = URL(string: "https://arcana.celesteai.ru/privacy")!
        let termsURL = URL(string: "https://arcana.celesteai.ru/terms")!
        appSettings.override(accountProviders: [InfoPlistReader.main.arcanaAccountProvider],
                             allowOtherAccountProviders: false,
                             hideBrandChrome: false,
                             pushGatewayBaseURL: baseURL,
                             oidcRedirectURL: URL(string: "https://arcana.celesteai.ru/oidc/login")!,
                             websiteURL: baseURL,
                             logoURL: URL(string: "https://arcana.celesteai.ru/mobile-icon.png")!,
                             copyrightURL: URL(string: "https://arcana.celesteai.ru/terms#copyright")!,
                             acceptableUseURL: termsURL,
                             privacyURL: privacyURL,
                             encryptionURL: privacyURL,
                             deviceVerificationURL: privacyURL,
                             chatBackupDetailsURL: privacyURL,
                             identityPinningViolationDetailsURL: privacyURL,
                             historySharingDetailsURL: privacyURL,
                             elementWebHosts: ["arcana.celesteai.ru"],
                             accountProvisioningHost: "",
                             bugReportApplicationID: "arcana-ios",
                             analyticsTermsURL: privacyURL,
                             mapTilerConfiguration: appSettings.mapTilerConfiguration)
        return appSettings
    }
}
