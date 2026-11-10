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
    /// False when the lid is closed (no built-in display anywhere).
    var builtinScreenPresent = true
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

    // MARK: Closed wings (SPEC §4.1)

    /// What the right wing shows.
    enum RightWing { case none, bars, time }

    /// A running timer or stopwatch beats the bars.
    var rightWingContent: RightWing {
        if TimerStore.shared.anyRunning || StopwatchStore.shared.isRunning { return .time }
        return SpotifyService.shared.isMusicActive ? .bars : .none
    }

    var leftWingWidth: CGFloat { SpotifyService.shared.isMusicActive ? geometry.wingWidth : 0 }

    var rightWingWidth: CGFloat {
        switch rightWingContent {
        case .none: 0
        case .bars: geometry.wingWidth
        case .time: max(geometry.wingWidth, NotchGeometry.timeWingWidth)
        }
    }

    var wingsVisible: Bool { leftWingWidth > 0 || rightWingWidth > 0 }
    var closedRect: CGRect { geometry.closedRect(left: leftWingWidth, right: rightWingWidth) }
    var hotZone: CGRect { geometry.hotZone(left: leftWingWidth, right: rightWingWidth) }

    /// Screen brightness only on the built-in display's notch (it would control the wrong display elsewhere).
    var showsScreenBrightness: Bool { isBuiltin && BrightnessService.shared.screenAvailable }
    /// Keyboard brightness on any notch, but only while the lid is open.
    var showsKeyboardBrightness: Bool { builtinScreenPresent && BrightnessService.shared.keyboardAvailable }

    /// Whether the black closed shape is drawn.
    var showsClosedShape: Bool { geometry.hasRealNotch || showFakeNotchWhenIdle }
}
