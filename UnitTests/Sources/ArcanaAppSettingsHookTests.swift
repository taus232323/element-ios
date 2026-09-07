//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import Arcana
import Testing

final class ArcanaAppSettingsHookTests {
    @Test
    func configureSetsArcanaAuthenticationDefaults() {
        let appSettings = ArcanaAppSettingsHook().configure(AppSettings())

        #expect(appSettings.accountProviders == [InfoPlistReader.main.arcanaAccountProvider])
        #expect(!appSettings.allowOtherAccountProviders)
        #expect(appSettings.pushGatewayBaseURL == URL(string: "https://arcana.celesteai.ru"))
        #expect(appSettings.websiteURL == URL(string: "https://arcana.celesteai.ru"))
        #expect(appSettings.privacyURL == URL(string: "https://arcana.celesteai.ru/privacy"))
        #expect(appSettings.bugReportApplicationID == "arcana-ios")
        #expect(appSettings.elementWebHosts == ["arcana.celesteai.ru"])
    }
}
