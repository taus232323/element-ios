//
// Copyright 2025 Element Creations Ltd.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import Arcana
import Combine
import Foundation
import Testing

@MainActor
struct AppCoordinatorDeepLinkTests {
    @Test
    func invitePreservesWindowType() throws {
        let appDelegate = AppDelegate()
        let appCoordinator = SpyAppCoordinator(appDelegate: appDelegate)
        let webURL = try #require(URL(string: "https://arcana.celesteai.ru/invite/token-123"))
        let encodedWebURL = try #require(webURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))

        let handled = try appCoordinator.handleDeepLink(#require(URL(string: "arcana://invite/token-123?web=\(encodedWebURL)")),
                                                        isExternalURL: false,
                                                        windowType: .settings)

        #expect(handled)
        #expect(appCoordinator.handledRoute == .invite(token: "token-123", webURL: webURL))
        #expect(appCoordinator.handledWindowType == .settings)
    }

    @Test
    func inviteIsPresentedAfterLogin() async throws {
        let appDelegate = AppDelegate()
        let appCoordinator = InviteSpyAppCoordinator(appDelegate: appDelegate)
        let webURL = try #require(URL(string: "https://arcana.celesteai.ru/invite/token-123"))
        let encodedWebURL = try #require(webURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let route = AppRoute.invite(token: "token-123", webURL: webURL)

        let handled = try appCoordinator.handleDeepLink(#require(URL(string: "arcana://invite/token-123?web=\(encodedWebURL)")),
                                                        isExternalURL: false,
                                                        windowType: nil)

        #expect(handled)
        #expect(appCoordinator.presentedInvite == nil)

        let deferred = deferFulfillment(appCoordinator.presentedInvites) { $0 == route }
        appCoordinator.authenticationFlowCoordinator(didLoginWithSession: UserSessionMock(.init()))

        try await deferred.fulfill()
        #expect(appCoordinator.presentedInvite == route)
    }
}

@MainActor
private final class SpyAppCoordinator: AppCoordinator {
    private(set) var handledRoute: AppRoute?
    private(set) var handledWindowType: SecondaryWindowType?

    override func handleAppRoute(_ appRoute: AppRoute, windowType: SecondaryWindowType?) {
        handledRoute = appRoute
        handledWindowType = windowType
    }
}

@MainActor
private final class InviteSpyAppCoordinator: AppCoordinator {
    private(set) var presentedInvite: AppRoute?
    let presentedInvites = PassthroughSubject<AppRoute, Never>()

    override func presentInviteScreen(token: String, webURL: URL?) {
        let route = AppRoute.invite(token: token, webURL: webURL)
        presentedInvite = route
        presentedInvites.send(route)
    }
}
