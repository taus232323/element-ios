//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The Arcana mark used on onboarding and authentication splash screens.
struct ArcanaMark: View {
    let size: CGFloat

    var body: some View {
        Image("images/arcana-mark")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The app's logo styled to fit on various launch pages.
struct AuthenticationStartLogo: View {
    /// Set to specify a custom size for the Logo, otherwise the default size of 158pt will be used.
    var size: CGFloat?
    /// Kept for compatibility with existing call sites.
    let hideBrandChrome: Bool
    /// Kept for compatibility with existing call sites.
    let isOnGradient: Bool

    var body: some View {
        ArcanaMark(size: size ?? 158)
    }
}

#Preview {
    VStack(spacing: 24) {
        AuthenticationStartLogo(hideBrandChrome: false, isOnGradient: false)
        AuthenticationStartLogo(size: 54, hideBrandChrome: false, isOnGradient: false)
    }
    .padding()
    .background(.compound.bgCanvasDefault)
}
