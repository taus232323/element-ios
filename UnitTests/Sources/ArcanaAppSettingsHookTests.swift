//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import Arcana
import Foundation
import Testing

final class ArcanaAppSettingsHookTests {
    @Test
    func configureSetsArcanaAuthenticationDefaults() throws {
        let baseURL = try #require(URL(string: "https://arcana.celesteai.ru"))
        let appSettings = ArcanaAppSettingsHook().configure(AppSettings.volatile())
        
        #expect(appSettings.accountProviders == [.managed(serverName: InfoPlistReader.main.arcanaAccountProvider,
                                                          baseURL: baseURL)])
        #expect(!appSettings.allowOtherAccountProviders)
        #expect(appSettings.pushGatewayBaseURL == baseURL)
        #expect(appSettings.websiteURL == baseURL)
        #expect(appSettings.privacyURL == URL(string: "https://arcana.celesteai.ru/privacy"))
        #expect(appSettings.bugReportApplicationID == "arcana-ios")
        #expect(appSettings.elementWebHosts == ["arcana.celesteai.ru"])
    }
}
