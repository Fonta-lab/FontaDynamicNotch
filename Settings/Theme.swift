import SwiftUI

/// Visual theme values. Only the "Default" theme exists until M9 (theme editor, JSON import/export).
struct Theme: Equatable, Sendable {
    // Corner rounding [Guess]
    var topFilletRadius: CGFloat = 12
    var openBottomRadius: CGFloat = 24
    var closedBottomRadius: CGFloat = 10
    // Shadow (open state only) [Guess]
    var shadowEnabled = true
    var shadowOpacity: Double = 0.35
    var shadowRadius: CGFloat = 12
    var shadowYOffset: CGFloat = 4

    static let `default` = Theme()
}
