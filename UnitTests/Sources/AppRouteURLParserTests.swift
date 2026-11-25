//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import Arcana
import Foundation
import Testing

@MainActor
struct AppRouteURLParserTests {
    var appSettings: AppSettings
    var appRouteURLParser: AppRouteURLParser
    
    init() {
        appSettings = AppSettings.volatile()
        appRouteURLParser = AppRouteURLParser(appSettings: appSettings)
    }
    
    @Test
    func oAuthCallbackRoute() {
        // Given an OAuth callback for this app.
        let callbackURL = appSettings.oAuthRedirectURL.appending(queryItems: [URLQueryItem(name: "state", value: "12345"),
                                                                              URLQueryItem(name: "code", value: "67890")])
        
        // When parsing that route.
        let route = appRouteURLParser.route(from: callbackURL)
        
        // Then it should be considered a valid OAuth callback.
        #expect(route == .oAuthCallback(url: callbackURL))
    }
    
    @Test
    func oAuthCallbackAppVariantRoute() {
        // Given an OAuth callback for a different app variant.
        let callbackURL = appSettings.oAuthRedirectURL
            .deletingLastPathComponent()
            .appending(component: "io.element.elementz")
            .appending(queryItems: [URLQueryItem(name: "state", value: "12345"),
                                    URLQueryItem(name: "code", value: "67890")])
        
        // When parsing that route in this app.
        let route = appRouteURLParser.route(from: callbackURL)
        
        // Then the route shouldn't be considered valid and should be ignored.
        #expect(route == nil)
    }
    
    @Test
    func matrixUserURL() throws {
        let userID = "@test:matrix.org"
        let url = try #require(URL(string: "https://matrix.to/#/\(userID)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .userProfile(userID: userID))
    }
    
    @Test
    func matrixRoomIdentifierURL() throws {
        let id = "!abcdefghijklmnopqrstuvwxyz1234567890:matrix.org"
        let url = try #require(URL(string: "https://matrix.to/#/\(id)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .room(roomID: id, via: []))
    }
    
    @Test
    func webRoomIDURL() throws {
        let id = "!abcdefghijklmnopqrstuvwxyz1234567890:matrix.org"
        let url = try #require(URL(string: "https://arcana.celesteai.ru/#/room/\(id)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .room(roomID: id, via: []))
    }
    
    @Test
    func webUserIDURL() throws {
        let id = "@alice:matrix.org"
        let url = try #require(URL(string: "https://arcana.celesteai.ru/#/user/\(id)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .userProfile(userID: id))
    }
    
    @Test
    func arcanaInviteCustomSchemeURL() throws {
        let webURL = try #require(URL(string: "https://arcana.celesteai.ru/invite/token-123"))
        let url = try #require(URL(string: "arcana://invite/token-123?web=\(webURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? webURL.absoluteString)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .invite(token: "token-123", webURL: webURL))
    }
    
    @Test
    func arcanaInviteUniversalLinkURL() throws {
        let webURL = try #require(URL(string: "https://arcana.celesteai.ru/invite/token-456"))
        let url = webURL
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .invite(token: "token-456", webURL: webURL))
    }
    
    @Test
    func arcanaInviteCustomSchemeWithExtraPathIsIgnored() throws {
        let url = try #require(URL(string: "arcana://invite/token-123/extra"))
        
        #expect(appRouteURLParser.route(from: url) == nil)
    }
    
    @Test
    func arcanaInviteUniversalLinkWithExtraPathIsIgnored() throws {
        let url = try #require(URL(string: "https://arcana.celesteai.ru/invite/token-456/extra"))
        
        #expect(appRouteURLParser.route(from: url) == nil)
    }
}
