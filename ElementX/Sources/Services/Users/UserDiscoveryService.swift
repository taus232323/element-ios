//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

final class UserDiscoveryService: UserDiscoveryServiceProtocol {
    private let clientProxy: ClientProxyProtocol
    
    init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
    }

    func searchProfiles(with searchQuery: String) async -> Result<[UserProfileProxy], UserDiscoveryErrorType> {
        async let queriedProfile = profileIfPossible(with: searchQuery)

        do {
            // Directory match is on localpart; strip a leading '@' so `@taus23` finds the user.
            let directoryTerm = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            async let searchedUsers = clientProxy.searchUsers(searchTerm: directoryTerm, limit: 10).get()
            let users = try await merge(queriedProfile: queriedProfile, searchResults: searchedUsers)
            return .success(filterAccountOwner(users))
        } catch {
            // we want to show the profile (if any) even if the search fails
            if let queriedProfile = await queriedProfile {
                return .success([queriedProfile])
            } else {
                return .failure(.failedSearchingUsers)
            }
        }
    }

    private func merge(queriedProfile: UserProfileProxy?, searchResults: SearchUsersResultsProxy) -> [UserProfileProxy] {
        let searchResults = searchResults.results
        
        guard let queriedProfile else {
            return searchResults
        }

        let filteredSearchResult = searchResults.filter {
            $0.userID != queriedProfile.userID
        }

        return [queriedProfile] + filteredSearchResult
    }
    
    private func profileIfPossible(with searchQuery: String) async -> UserProfileProxy? {
        guard let userID = resolveUserID(from: searchQuery), userID != clientProxy.userID else {
            return nil
        }
        
        let getProfileResult = try? await clientProxy.profile(for: userID).get()
        
        // fallback to a "local profile" if the profile api fails
        return getProfileResult ?? .init(userID: userID)
    }

    /// Resolve `alice`, `@alice`, or `@alice:server` to a full MXID on this homeserver.
    private func resolveUserID(from searchQuery: String) -> String? {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isMatrixIdentifier {
            return trimmed
        }
        let localpart = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        guard !localpart.isEmpty,
              !localpart.contains(":"),
              !localpart.contains(" "),
              let serverName = clientProxy.userIDServerName else {
            return nil
        }
        let fullID = "@\(localpart):\(serverName)"
        return fullID.isMatrixIdentifier ? fullID : nil
    }

    private func filterAccountOwner(_ profiles: [UserProfileProxy]) -> [UserProfileProxy] {
        let accountOwnerID = clientProxy.userID
        return profiles.filter { $0.userID != accountOwnerID }
    }
}

private extension String {
    var isMatrixIdentifier: Bool {
        MatrixEntityRegex.isMatrixUserIdentifier(self)
    }
}
