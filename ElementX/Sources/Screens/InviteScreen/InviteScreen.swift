//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import Foundation
import SwiftUI

struct InviteScreen: View {
    let token: String
    let webURL: URL
    let clientProxy: ClientProxyProtocol?
    let onOpenRoom: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var loadState: LoadState = .loading
    @State private var invite: ArcanaInvitePreview?
    @State private var errorMessage: String?
    @State private var isAccepting = false
    @State private var acceptErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AuthenticationStartLogo(size: 104, hideBrandChrome: false, isOnGradient: false)

                VStack(spacing: 12) {
                    Text(UntranslatedL10n.screenArcanaInviteTitleIos)
                        .font(.title2.weight(.semibold))

                    Text(UntranslatedL10n.screenArcanaInviteDescriptionIos)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                switch loadState {
                case .loading:
                    ProgressView()
                        .padding(.vertical, 8)
                case .loaded:
                    VStack(spacing: 16) {
                        if let inviter = invite?.inviterDisplayName ?? invite?.inviterUserId {
                            infoCard(title: L10n.screenJoinRoomInvitedBy, value: inviter)
                        }
                        if let roomName = invite?.roomName ?? invite?.roomId {
                            infoCard(title: L10n.commonRoomName, value: roomName)
                        }
                        if let target = invite?.targetDisplayName ?? invite?.targetUserId {
                            infoCard(title: L10n.commonName, value: target)
                        }
                        infoCard(title: UntranslatedL10n.screenArcanaInviteTokenIos, value: token)
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        if let acceptErrorMessage {
                            Text(acceptErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                case .failed:
                    Text(L10n.screenJoinRoomInviteRequiredMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Button {
                        guard let invite else {
                            webURL.openInSystemBrowser()
                            return
                        }

                        if invite.used == true, let roomID = invite.roomId {
                            dismiss()
                            onOpenRoom(roomID)
                            return
                        }

                        if clientProxy == nil {
                            webURL.openInSystemBrowser()
                            return
                        }

                        Task { await acceptInvite() }
                    } label: {
                        Text(primaryButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAccepting)

                    Button {
                        webURL.openInSystemBrowser()
                    } label: {
                        Text(UntranslatedL10n.actionOpenBrowserPageIos)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        dismiss()
                    } label: {
                        Text(L10n.actionClose)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: 560)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.compound.bgCanvasDefault)
        .task(id: token) {
            await loadInvite()
        }
    }

    private var primaryButtonTitle: String {
        guard let invite else {
            return UntranslatedL10n.actionOpenBrowserPageIos
        }
        if invite.used == true, invite.roomId != nil {
            return L10n.actionContinue
        }
        if clientProxy != nil {
            return L10n.actionAccept
        }
        return UntranslatedL10n.actionOpenBrowserPageIos
    }

    @MainActor
    private func loadInvite() async {
        loadState = .loading
        errorMessage = nil
        acceptErrorMessage = nil
        do {
            invite = try await ArcanaInviteClient.loadInvite(token: token)
            loadState = .loaded
        } catch {
            MXLog.error("Failed loading Arcana invite with error: \(error)")
            errorMessage = L10n.errorUnknown
            loadState = .failed
        }
    }

    @MainActor
    private func acceptInvite() async {
        guard let clientProxy else {
            webURL.openInSystemBrowser()
            return
        }
        guard let invite else {
            return
        }
        guard !isAccepting else {
            return
        }

        isAccepting = true
        acceptErrorMessage = nil
        do {
            let roomID = try await ArcanaInviteClient.acceptInvite(token: invite.token, accessToken: clientProxy.accessToken)
            isAccepting = false
            dismiss()
            onOpenRoom(roomID)
        } catch {
            isAccepting = false
            acceptErrorMessage = L10n.errorUnknown
            MXLog.error("Failed accepting Arcana invite with error: \(error)")
        }
    }

    private func infoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.compound.bgSubtlePrimary))
    }
}

private enum LoadState {
    case loading
    case loaded
    case failed
}

private struct ArcanaInvitePreview: Decodable {
    let token: String
    let kind: String?
    let inviter: ArcanaInviteIdentity?
    let target: ArcanaInviteIdentity?
    let room: ArcanaInviteRoom?
    let webURL: String?
    let expiresAt: String?
    let used: Bool?

    var inviterDisplayName: String? {
        inviter?.displayName
    }

    var inviterUserId: String? {
        inviter?.userId
    }

    var targetDisplayName: String? {
        target?.displayName
    }

    var targetUserId: String? {
        target?.userId
    }

    var roomName: String? {
        room?.roomName
    }

    var roomId: String? {
        room?.roomId
    }
}

private struct ArcanaInviteIdentity: Decodable {
    let userId: String?
    let displayName: String?
    let avatarUrl: String?
}

private struct ArcanaInviteRoom: Decodable {
    let roomId: String?
    let roomName: String?
    let isDm: Bool?
}

private enum ArcanaInviteClient {
    private static let baseURL = URL(string: "https://\(InfoPlistReader.main.arcanaInviteWebHost)")!
    private static let decoder = JSONDecoder()

    static func loadInvite(token: String) async throws -> ArcanaInvitePreview {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("invite")
            .appendingPathComponent(token)
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(ArcanaInvitePreview.self, from: data)
    }

    static func acceptInvite(token: String, accessToken: String) async throws -> String {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("invite")
            .appendingPathComponent(token)
            .appendingPathComponent("accept")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        let payload = try decoder.decode(ArcanaInviteAcceptResponse.self, from: data)
        return payload.roomID
    }
}

private struct ArcanaInviteAcceptResponse: Decodable {
    let roomID: String
    let isNew: Bool?
    let openRoom: Bool?

    enum CodingKeys: String, CodingKey {
        case roomID = "roomId"
        case isNew
        case openRoom
    }
}

// MARK: - Previews

struct InviteScreen_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        InviteScreen(token: "token-123",
                     webURL: URL(string: "https://arcana.celesteai.ru/invite/token-123")!,
                     clientProxy: nil,
                     onOpenRoom: { _ in })
            .previewDisplayName("Default")
    }
}
