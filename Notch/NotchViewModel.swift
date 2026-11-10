import Foundation
import Observation

/// Reasons the open notch must not close when the mouse leaves (SPEC §4.2).
enum CloseBlocker: String, Hashable, Sendable {
    case mouseDown = "mouse button held"
    case contextMenu = "right-click menu"
    case alarm = "alarm ringing"        // M6
    case outputList = "output list"     // M4
    case fileDrag = "file drag"         // M8
}

/// Per-screen state that the SwiftUI notch view draws.
@MainActor @Observable
final class NotchViewModel {
    var geometry: NotchGeometry
    var theme = Theme.default
    var screenName: String
    var isBuiltin: Bool
    var showFakeNotchWhenIdle: Bool
    var showDebugOverlay: Bool
    var isFullscreenHidden = false
    var isMouseInside = false
    var isOpen = false
    var closeBlockers: Set<CloseBlocker> = []
    /// Bumped when the user clicks outside the notch, so popups (output list) close.
    var dismissToken = 0
    @ObservationIgnored var blockerHandler: ((CloseBlocker, Bool) -> Void)?

    init(geometry: NotchGeometry, screenName: String, isBuiltin: Bool, settings: AppSettings) {
        self.geometry = geometry
        self.screenName = screenName
        self.isBuiltin = isBuiltin
        self.showFakeNotchWhenIdle = settings.showFakeNotchWhenIdle
        self.showDebugOverlay = settings.showDebugOverlay
    }

    /// Closed wings are visible while music is active (timers join in M6).
    var wingsVisible: Bool { SpotifyService.shared.isMusicActive }

    /// Whether the black closed shape is drawn.
    var showsClosedShape: Bool { geometry.hasRealNotch || showFakeNotchWhenIdle }
}
