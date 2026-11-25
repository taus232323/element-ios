//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

#if IS_MAIN_APP
import EmbeddedElementCall
#endif

import Combine
import Foundation
import Macros
import SwiftUI

nonisolated enum AppBuildType {
    case debug
    case nightly
    case release
    
    static var current: AppBuildType {
        #if DEBUG
        return .debug
        #else
        if InfoPlistReader.main.isNightlyBuild {
            .nightly
        } else {
            .release
        }
        #endif
    }
}

/// Store Arcana app settings.
///
/// State is persisted in `UserDefaults`, which is thread-safe per Apple's documentation, hence `@unchecked`.
final nonisolated class AppSettings: @unchecked Sendable {
    static let suiteName: String = InfoPlistReader.main.appGroupIdentifier
    
    /// UserDefaults to be used on reads and writes.
    private let store: UserDefaultsProtocol
    
    static var appBuildType: AppBuildType {
        AppBuildType.current
    }
    
    func resetAllSettings() {
        MXLog.warning("Resetting the AppSettings.")
        store.reset()
    }
    
    // MARK: - Hooks
    
    // swiftlint:disable:next function_parameter_count
    func override(accountProviders: [AccountProvider],
                  allowOtherAccountProviders: Bool,
                  hideBrandChrome: Bool,
                  pushGatewayBaseURL: URL,
                  oAuthRedirectURL: URL,
                  oAuthClientURIPath: String?,
                  websiteURL: URL,
                  logoURL: URL,
                  copyrightURL: URL,
                  acceptableUseURL: URL,
                  privacyURL: URL,
                  encryptionURL: URL,
                  deviceVerificationURL: URL,
                  chatBackupDetailsURL: URL,
                  identityPinningViolationDetailsURL: URL,
                  historySharingDetailsURL: URL,
                  elementWebHosts: [String],
                  accountProvisioningHost: String,
                  bugReportApplicationID: String,
                  analyticsTermsURL: URL?,
                  bundledMapTilerConfiguration: MapTilerConfiguration) {
        self.accountProviders = accountProviders
        self.allowOtherAccountProviders = allowOtherAccountProviders
        self.hideBrandChrome = hideBrandChrome
        self.pushGatewayBaseURL = pushGatewayBaseURL
        self.oAuthRedirectURL = oAuthRedirectURL
        self.oAuthClientURIPath = oAuthClientURIPath
        self.websiteURL = websiteURL
        self.logoURL = logoURL
        self.copyrightURL = copyrightURL
        self.acceptableUseURL = acceptableUseURL
        self.privacyURL = privacyURL
        self.encryptionURL = encryptionURL
        self.deviceVerificationURL = deviceVerificationURL
        self.chatBackupDetailsURL = chatBackupDetailsURL
        self.identityPinningViolationDetailsURL = identityPinningViolationDetailsURL
        self.historySharingDetailsURL = historySharingDetailsURL
        self.elementWebHosts = elementWebHosts
        self.accountProvisioningHost = accountProvisioningHost
        self.bugReportApplicationID = bugReportApplicationID
        self.analyticsTermsURL = analyticsTermsURL
        self.bundledMapTilerConfiguration = bundledMapTilerConfiguration
    }
    
    // MARK: - Application
    
    /// The last known version of the app that was launched on this device, which is
    /// used to detect when migrations should be run. When `nil` the app may have been
    /// deleted between runs so should clear data in the shared container and keychain.
    @UserPreference
    var lastVersionLaunched: String?
    
    /// Whether a user session has ever been set up on this device. Deliberately not cleared on
    /// logout: it stops the Classic app migration prompt from reappearing when an Element X
    /// user is signed out unexpectedly (invalidated token, corrupted storage, etc).
    @UserPreference(defaultValue: false)
    var hasSignedInBefore: Bool
    
    /// Defaults to `true` for new users, and we use a migration to set it to `false` for existing users.
    @UserPreference(defaultValue: true)
    var hasSeenNewSoundBanner: Bool
    
    /// Defaults to `true` so new users never see it. Developer options arms it for now, an upgrade migration will at launch.
    @UserPreference(defaultValue: true)
    var hasSeenMultiAccountAnnouncement: Bool
    
    /// Whether Settings lists the other accounts, rather than only showing their avatars.
    @UserPreference(defaultValue: true)
    var hasExpandedAccountPicker: Bool
    
    /// The initial set of account providers shown to the user in the authentication flow.
    ///
    /// Account provider is the friendly term for the server name. It should not contain an `https` prefix and should
    /// match the last part of the user ID. For example `example.com` and not `https://matrix.example.com`.
    private(set) var accountProviders: [AccountProvider] = [.managed(serverName: "arcana.celesteai.ru", baseURL: "https://arcana.celesteai.ru")]
    /// Whether or not the user is allowed to manually enter their own account provider or must select from one of `defaultAccountProviders`.
    private(set) var allowOtherAccountProviders = false
    /// Whether the components surrounding the app brand/logo should be hidden or not
    private(set) var hideBrandChrome = false
    
    /// The task identifier used for background app refresh. Also used in main target's the Info.plist
    let backgroundAppRefreshTaskIdentifier = "io.arcana.arcana.background.refresh"
    /// The task identifier used for the search index backfill. Also used in the main target's Info.plist.
    let searchBackfillTaskIdentifier = "io.arcana.arcana.background.search-backfill"
    
    /// A URL where users can go read more about the app.
    private(set) var websiteURL: URL = "https://arcana.celesteai.ru"
    /// A URL that contains the app's logo that may be used when showing content in a web view.
    private(set) var logoURL: URL = "https://arcana.celesteai.ru/mobile-icon.png"
    /// A URL that contains that app's copyright notice.
    private(set) var copyrightURL: URL = "https://arcana.celesteai.ru/terms#copyright"
    /// A URL that contains the app's Terms of use.
    private(set) var acceptableUseURL: URL = "https://arcana.celesteai.ru/terms"
    /// A URL that contains the app's Privacy Policy.
    private(set) var privacyURL: URL = "https://arcana.celesteai.ru/privacy"
    /// A URL where users can go read more about encryption in general.
    private(set) var encryptionURL: URL = "https://arcana.celesteai.ru/privacy"
    /// A URL where users can go read more about device verification.
    private(set) var deviceVerificationURL: URL = "https://arcana.celesteai.ru/privacy"
    /// A URL where users can go read more about the chat backup.
    private(set) var chatBackupDetailsURL: URL = "https://arcana.celesteai.ru/privacy"
    /// A URL where users can go read more about identity pinning violations
    private(set) var identityPinningViolationDetailsURL: URL = "https://arcana.celesteai.ru/privacy"
    /// A URL describing how history sharing works
    private(set) var historySharingDetailsURL: URL = "https://arcana.celesteai.ru/privacy"
    
    /// Domains that Arcana web may be hosted on - used for handling permalink-style links.
    private(set) var elementWebHosts = ["arcana.celesteai.ru"]
    /// Unused for Arcana invite flows (kept for upstream API compatibility).
    private(set) var accountProvisioningHost = ""
    /// Shown only if a homeserver demands a “Pro” client — unused for Arcana.
    let elementProAppStoreURL: URL = "https://arcana.celesteai.ru"
    
    @UserPreference(defaultValue: AppAppearance.system)
    var appAppearance: AppAppearance
    
    /// Tracks previous servers the user connected to for autocompletion purposes. Entries are made lowercase on write.
    @UserPreference(key: "previousServers", defaultValue: [])
    var previousServers: [String]
    
    var defaultAccountProvider: AccountProvider {
        if allowOtherAccountProviders {
            previousServers.first.map { .generic($0) } ?? accountProviders[0]
        } else {
            accountProviders[0]
        }
    }
    
    // MARK: - Security
    
    /// The app must be locked with a PIN code as part of the authentication flow.
    let appLockIsMandatory = false
    /// The amount of time the app can remain in the background for without requesting the PIN/TouchID/FaceID.
    let appLockGracePeriod: TimeInterval = 0
    /// Any codes that the user isn't allowed to use for their PIN.
    let appLockPINCodeBlockList = ["0000", "1234"]
    /// The number of attempts the user has made to unlock the app with a PIN code (resets when unlocked).
    @UserPreference(defaultValue: 0)
    var appLockNumberOfPINAttempts: Int
    
    // MARK: - Authentication
    
    /// Any pre-defined static client registrations for OAuth issuers.
    let oAuthStaticRegistrations: [URL: String] = [:]
    /// The redirect URL used for OAuth. Arcana's callback host must match the associated webcredentials.
    private(set) nonisolated(unsafe) var oAuthRedirectURL: URL! = URL(string: "https://arcana.celesteai.ru/oidc/login")
    /// A path that is appended to `websiteURL` to form the OAuth `clientURI`. MAS uses `clientURI` as the identifier for a specific app, allowing us to
    /// distinguish the various clients we have for Android, iOS and Web from each other.
    /// Intentionally a distinct property so it can be easily overridden without having to manipulate the website URL.
    private(set) var oAuthClientURIPath: String? = "apps/ios"
    
    var oAuthConfiguration: OAuthConfiguration {
        OAuthConfiguration(clientName: InfoPlistReader.main.bundleDisplayName,
                           redirectURI: oAuthRedirectURL,
                           clientURI: oAuthClientURIPath.map { websiteURL.appending(path: $0) } ?? websiteURL,
                           logoURI: logoURL,
                           tosURI: acceptableUseURL,
                           policyURI: privacyURL,
                           staticRegistrations: oAuthStaticRegistrations.mapKeys { $0.absoluteString })
    }
    
    /// Whether or not the Create Account button is shown on the start screen.
    ///
    /// **Note:** Setting this to false doesn't prevent someone from creating an account when the selected homeserver's MAS allows registration.
    let showCreateAccountButton = true
    
    // MARK: - Notifications
    
    var pusherAppID: String {
        #if DEBUG
        InfoPlistReader.main.baseBundleIdentifier + ".ios.dev"
        #else
        InfoPlistReader.main.baseBundleIdentifier + ".ios.prod"
        #endif
    }
    
    private(set) var pushGatewayBaseURL: URL = "https://arcana.celesteai.ru"
    var pushGatewayNotifyEndpoint: URL {
        pushGatewayBaseURL.appending(path: "_matrix/push/v1/notify")
    }
    
    @UserPreference(defaultValue: false)
    var hasRunNotificationPermissionsOnboarding: Bool
    
    /// The device's last boot time as recorded by the NSE.
    @UserPreference
    var lastNotificationBootTime: TimeInterval?
    
    /// The app icon badge value the app last computed from the SDK's unread notification counts.
    @UserPreference(defaultValue: 0)
    var lastKnownBadgeCount: Int
    
    // MARK: - Logging
    
    @UserPreference(defaultValue: LogLevel.info)
    var logLevel: LogLevel
    
    @UserPreference(defaultValue: Set<TraceLogPack>())
    var traceLogPacks: Set<TraceLogPack>
    
    // MARK: - Bug report
    
    let bundledBugReportRageshakeConfiguration: RageshakeConfiguration = Secrets.rageshakeURL.map { .url(URL(string: $0)!) } ?? .disabled // swiftlint:disable:this force_unwrapping
    let bugReportSentryURL: URL? = Secrets.sentryDSN.map { URL(string: $0)! } // swiftlint:disable:this force_unwrapping
    let bugReportSentryRustURL: URL? = Secrets.sentryRustDSN.map { URL(string: $0)! } // swiftlint:disable:this force_unwrapping
    /// The name allocated by the bug report server
    private(set) var bugReportApplicationID = "arcana-ios"
    
    // MARK: - Analytics
    
    /// The configuration to use for analytics. Set to `nil` to disable analytics.
    let analyticsConfiguration: AnalyticsConfiguration? = AppSettings.makeAnalyticsConfiguration()
    /// The URL to open with more information about analytics terms. When this is `nil` the "Learn more" link will be hidden.
    private(set) var analyticsTermsURL: URL? = "https://arcana.celesteai.ru/privacy"
    /// Whether or not there the app is able ask for user consent to enable analytics or sentry reporting.
    var canPromptForAnalytics: Bool {
        analyticsConfiguration != nil || bugReportSentryURL != nil
    }
    
    private static func makeAnalyticsConfiguration() -> AnalyticsConfiguration? {
        guard let host = Secrets.postHogHost, let apiKey = Secrets.postHogAPIKey else { return nil }
        return AnalyticsConfiguration(host: host, apiKey: apiKey)
    }
    
    /// Whether the user has opted in to send analytics.
    ///
    /// **Note:** Opt-in is app-wide, not per-session.
    @UserPreference(defaultValue: AnalyticsConsentState.unknown)
    var analyticsConsentState: AnalyticsConsentState
    
    // MARK: - Live Location
    
    /// Live location requires Always location authorization.
    /// Forced off on every launch for App Store compliance (Guideline 2.5.4); static pin sharing remains.
    @UserPreference(defaultValue: false)
    var liveLocationSharingEnabled: Bool
    
    @UserPreference(defaultValue: 10)
    var liveLocationMinimumDistanceUpdate: Int
    
    @UserPreference(defaultValue: false)
    var liveLocationDisclaimerDisplayed: Bool
    
    @UserPreference(defaultValue: false)
    var hasRequestedLocationAlwaysLocationAuthorization: Bool
    
    // MARK: - Room Screen
    
    @UserPreference(defaultValue: AppBuildType.current == .debug)
    var viewSourceEnabled: Bool
    
    @UserPreference(defaultValue: true)
    var optimizeMediaUploads: Bool
    
    @UserPreference(defaultValue: AudioPlaybackSpeed.default)
    var voiceMessagePlaybackSpeed: AudioPlaybackSpeed
    
    @UserPreference(defaultValue: [FrequentlyUsedEmoji]())
    var frequentlyUsedSystemEmojis: [FrequentlyUsedEmoji]
    
    /// Whether or not to show a warning on the media caption composer so the user knows
    /// that captions might not be visible to users who are using other Matrix clients.
    let shouldShowMediaCaptionWarning = true
    
    // MARK: - Calls
    
    #if IS_MAIN_APP
    // swiftlint:disable:next force_unwrapping
    let elementCallBaseURL: URL = EmbeddedElementCall.appURL!
    #endif
    
    /// Intentionally empty — do not send call analytics to Element infrastructure.
    let elementCallPosthogAPIHost = ""
    let elementCallPosthogAPIKey = ""
    let elementCallPosthogSentryDSN = ""
    
    @UserPreference
    var elementCallBaseURLOverride: URL?
    
    // MARK: - Users
    
    /// Whether to hide the display name and avatar of ignored users as these may contain objectionable content.
    let hideIgnoredUserProfiles = true
    
    // MARK: - Maps
    
    /// The locally-bundled MapTiler configuration.
    private(set) var bundledMapTilerConfiguration = MapTilerConfiguration(baseURL: "https://api.maptiler.com/maps",
                                                                          apiKey: Secrets.mapLibreAPIKey,
                                                                          lightStyleID: "9bc819c8-e627-474a-a348-ec144fe3d810",
                                                                          darkStyleID: "dea61faf-292b-4774-9660-58fcef89a7f3")
    
    // MARK: - Feature Flags
    
    @UserPreference(defaultValue: AppBuildType.current != .release)
    var developerOptionsEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var fuzzyRoomListSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var lowPriorityFilterEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var mentionsFilterEnabled: Bool
    
    /// Puts the invites filter first while there are invites and hides it when there are none.
    @UserPreference(defaultValue: false)
    var prominentInvitesFilterEnabled: Bool
    
    /// Configuration to enable only signed device isolation mode for  crypto. In this mode only devices signed by their owner will be considered in e2ee rooms.
    @UserPreference(defaultValue: false)
    var enableOnlySignedDeviceIsolationMode: Bool
    
    @UserPreference(defaultValue: false)
    var knockingEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var threadsEnabled: Bool
    
    @UserPreference(key: "globalSearchEnabledV2", defaultValue: true)
    var globalSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var focusEventOnNotificationTap: Bool
    
    @UserPreference(defaultValue: false)
    var linkPreviewsEnabled: Bool
    
    /// Enables *sending* gallery messages (multiple media in a single message).
    /// Received galleries are always rendered regardless of this flag.
    @UserPreference(defaultValue: false)
    var galleryEnabled: Bool
    
    /// Adds a pencil next to crop in the media upload preview, to draw on pictures before sending them.
    @UserPreference(defaultValue: false)
    var imageDrawingEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var jumpToReadMarkerEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var linkNewDeviceEnabled: Bool
    
    @UserPreference(key: "clientPausingAndResumingEnabledV2", defaultValue: false, volatile: true)
    var clientPausingAndResumingEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var hideQuietNotificationAlerts: Bool
    
    /// Runs calls through the native matrix-rust-rtc stack instead of the Element Call web view.
    @UserPreference(defaultValue: false)
    var nativeCallEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var multiAccountEnabled: Bool
    
    /// Lets it snow on top of the whole app.
    @UserPreference(defaultValue: false)
    var snowEnabled: Bool
    
    init(store: UserDefaultsProtocol) {
        self.store = store
        // App Store builds do not include UIBackgroundModes location.
        liveLocationSharingEnabled = false
    }
    
    func userSettings(for userID: String) -> UserSettings {
        UserSettings(appSettings: self, accountSettings: .init(userID: userID,
                                                               store: store,
                                                               bundledMapTilerConfiguration: bundledMapTilerConfiguration,
                                                               bundledBugReportRageshakeConfiguration: bundledBugReportRageshakeConfiguration))
    }
    
    static func volatile() -> AppSettings {
        AppSettings(store: VolatileUserDefaults())
    }
}
