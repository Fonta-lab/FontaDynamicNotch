import SwiftUI

/// Visual theme values. Only the "Default" theme exists until M9 (theme editor, JSON import/export).
/// Values marked [Guess] are starting points to tune.
struct Theme: Equatable, Sendable {
    // Colours
    var fallbackBackground = Color.black
    var primaryText = Color.white
    var secondaryText = Color.white.opacity(0.6)
    var accent = Color.white
    var iconColor = Color.white
    var sliderTrack = Color.white.opacity(0.2)
    var sliderFill = Color.white
    var sliderKnob = Color.white
    var useArtworkColor = true
    var artworkIntensity: Double = 1.0
    var minTextContrast: Double = 4.5          // "max background brightness"
    var notchBlendRadius: CGFloat = 60

    // Corner rounding [Guess]
    var topFilletRadius: CGFloat = 12
    var openBottomRadius: CGFloat = 24
    var closedBottomRadius: CGFloat = 10
    var coverRadiusOpen: CGFloat = 12
    var coverRadiusClosed: CGFloat = 5
    var buttonRadius: CGFloat = 8

    // Shadow (open state only) [Guess]
    var shadowEnabled = true
    var shadowOpacity: Double = 0.35
    var shadowRadius: CGFloat = 12
    var shadowYOffset: CGFloat = 4

    // Sizes [Guess]
    var controlIconSize: CGFloat = 16
    var sliderHeight: CGFloat = 4
    var knobSize: CGFloat = 10

    static let `default` = Theme()
}
