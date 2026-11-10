import SwiftUI

/// Open-state background (SPEC §4.4): the cover's dominant colour, or the theme's fallback colour.
/// No fade around the notch (removed at the user's request after M3).
struct NotchBackgroundView: View {
    let theme: Theme
    let color: Color?

    var body: some View {
        if let color { color } else { theme.fallbackBackground }
    }
}
