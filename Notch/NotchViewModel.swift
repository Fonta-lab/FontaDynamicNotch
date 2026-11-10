import Foundation
import Observation

/// Per-screen state that the SwiftUI notch view draws.
@MainActor @Observable
final class NotchViewModel {
    var geometry: NotchGeometry
    var screenName: String
    var isBuiltin: Bool
    var showFakeNotchWhenIdle: Bool
    var showDebugOverlay: Bool
    var isFullscreenHidden = false
    var isMouseInside = false

    init(geometry: NotchGeometry, screenName: String, isBuiltin: Bool, settings: AppSettings) {
        self.geometry = geometry
        self.screenName = screenName
        self.isBuiltin = isBuiltin
        self.showFakeNotchWhenIdle = settings.showFakeNotchWhenIdle
        self.showDebugOverlay = settings.showDebugOverlay
    }

    /// Whether the black closed shape is drawn.
    var showsClosedShape: Bool { geometry.hasRealNotch || showFakeNotchWhenIdle }
}
