import SwiftUI

/// The built-in theme list and the Liquid Glass helpers.
extension Theme {
    /// Only one built-in theme: Default. Its Surface can be Solid or Liquid Glass.
    static let builtInIDs: Set<String> = [defaultID]
    static let builtIns: [Theme] = [.default]

    var isGlass: Bool { surfaceStyle == .liquidGlass }

    /// Opacity of the whole glass (glass + legibility layer): at the "Clear" end only a faint glass
    /// is left, so what's behind shows through almost unchanged.
    var glassLayerOpacity: Double { 0.12 + 0.88 * min(1, max(0, glassOpacity)) }

    /// The colour the glass is tinted with, already at its strength (nil = clear glass).
    /// While music plays and "Use artwork colour" is on, the cover colour wins over the custom tint.
    /// It goes through the same darkening as the solid background, so white text keeps its contrast.
    func glassTint(artwork: RGBColor?) -> Color? {
        if useArtworkColor, let artwork {
            let c = artwork.scaled(artworkIntensity).darkened(toMaxLuminance: maxBackgroundLuminance)
            return c.color.opacity(glassTintIntensity)
        }
        guard glassTintEnabled, glassTintIntensity > 0 else { return nil }
        return glassTintColor.color.opacity(glassTintIntensity * glassTintColor.a)
    }

    @available(macOS 26, *)
    /// The glass itself, untinted (the tint is drawn as a separate layer in NotchSurfaceView).
    func glass() -> Glass {
        // Swapped on purpose: inside the notch (forced dark look, plus our dimming layer) the system's
        // `.regular` glass looks the more see-through of the two on macOS 27, so "Clear" in Settings
        // uses it and "Regular" uses `.clear`. Tested by eye by the user (v0.3).
        return glassVariant == .clear ? .regular : .clear
    }
}

enum GlassSupport {
    /// True on macOS 26 and later, where the real Liquid Glass is drawn.
    static var isFullGlassAvailable: Bool {
        if #available(macOS 26, *) { return !forceFallback }
        return false
    }

    /// Debug switch to see the macOS 14/15 fallback on a newer Mac:
    /// `defaults write com.fonta.dynamicnotch ForceGlassFallback -bool YES`, then relaunch.
    static let forceFallback = UserDefaults.standard.bool(forKey: "ForceGlassFallback")
}
