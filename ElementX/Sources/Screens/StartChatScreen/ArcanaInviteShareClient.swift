//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum ArcanaInviteShareClient {
    private static let baseURL = URL(string: "https://\(InfoPlistReader.main.arcanaInviteWebHost)")!
    private static let decoder = JSONDecoder()

    static func inviteURL(forUserID userID: String) -> URL {
        URL(string: "https://\(InfoPlistReader.main.arcanaInviteWebHost)/invite/\(percentEncodedInvitePathComponent(userID))")!
    }

    static func createInvite(accessToken: String) async throws -> URL {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("invite")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let payload = try decoder.decode(ArcanaInviteShareResponse.self, from: data)
        if let webURL = payload.webURL.flatMap(URL.init(string:)) {
            return webURL
        }

        return URL(string: "https://\(InfoPlistReader.main.arcanaInviteWebHost)/invite/\(percentEncodedInvitePathComponent(payload.token))")!
    }

    private static func percentEncodedInvitePathComponent(_ value: String) -> String {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
    }
}

private struct ArcanaInviteShareResponse: Decodable {
    let token: String
    let webURL: String?

    enum CodingKeys: String, CodingKey {
        case token
        case webURL = "webUrl"
    }
}
