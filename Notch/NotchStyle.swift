import SwiftUI
import AppKit

/// Spacing inside the notch, on Apple's 4/8 pt grid. Same kind of gap = same constant everywhere.
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

/// Strength of the soft fills behind buttons and panels. They're drawn in the theme's primary
/// text colour, so a theme with dark text gets dark highlights.
enum Highlight {
    /// Resting fill of panels and groups (tool panel, shelf, drop zones, Home/Files pair).
    static let panel = 0.08
    /// Resting fill of filled buttons (tool panel buttons, "Open Spotify").
    static let filled = 0.10
    static let hover = 0.12
    /// Selected item (current tool, tab, timer chip, shelf file) and active drop target.
    static let selected = 0.18
    static let pressed = 0.22
}

extension Theme {
    /// Panels inside the notch (tool panel, shelf, drop zones). Their buttons sit `Spacing.s` in,
    /// so the panel corner is the button corner plus that gap: the two curves stay concentric
    /// and follow the theme's "Buttons" corner setting.
    var panelRadius: CGFloat { buttonRadius + Spacing.s }

    /// The theme's button corner, but never more than half the button's height (it'd be a capsule).
    func buttonRadius(height: CGFloat) -> CGFloat { min(buttonRadius, height / 2) }
}

/// Height of every button in the open notch's top bar.
enum TopBarMetrics {
    static let itemHeight: CGFloat = 24
}

/// Small animations inside the notch. The big ones (open, close, wings, tabs…) are the user's
/// springs from Settings › Animations.
/// With Reduce Motion on (System Settings › Accessibility › Display) every one of them, and every
/// user spring, becomes a short fade.
enum Motion {
    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    /// What replaces springs, bounces and scales when Reduce Motion is on.
    static let reducedFade = Animation.easeOut(duration: 0.15)

    /// Hover, press, toggle: a quick spring with a hint of bounce.
    static var feedback: Animation { reduceMotion ? reducedFade : .snappy(duration: 0.25) }
    /// Small things appearing or changing (output list, lap list, drop targets): smooth, no bounce.
    static var change: Animation { reduceMotion ? reducedFade : .smooth(duration: 0.3) }
    /// The open content waits this long, so the notch starts growing before the content shows.
    static let contentDelay: Double = 0.05
    /// Content leaving on close: quicker than the shape, so it's gone before the notch shrinks.
    static var contentOut: Animation { reduceMotion ? reducedFade : .smooth(duration: 0.15) }
}
