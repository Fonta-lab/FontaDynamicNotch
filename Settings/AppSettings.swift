import Foundation

/// All user settings. Every key decodes with a default, so adding settings later never wipes the file.
struct AppSettings: Codable, Equatable, Sendable {
    var schemaVersion = 1
    // General
    var notchOnAllScreens = true
    var showFakeNotchWhenIdle = true
    var hoverOpenDelay: Double = 0.10
    var closeDelay: Double = 0
    var pausedMusicVisibleMinutes: Double = 10
    // Music
    var musicBarCount = 5
    var musicBarSpeed: Double = 1.0
    var musicBarsUseArtworkColor = true
    var marqueeEnabled = true
    // Animations
    var animations = AnimationSettings()
    // Layout
    var openWidth: Double = 600
    var openHeight: Double = 190
    var closedWingWidth: Double = 40
    // Advanced
    var showDebugOverlay = false

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? d.schemaVersion
        notchOnAllScreens = try c.decodeIfPresent(Bool.self, forKey: .notchOnAllScreens) ?? d.notchOnAllScreens
        showFakeNotchWhenIdle = try c.decodeIfPresent(Bool.self, forKey: .showFakeNotchWhenIdle) ?? d.showFakeNotchWhenIdle
        hoverOpenDelay = try c.decodeIfPresent(Double.self, forKey: .hoverOpenDelay) ?? d.hoverOpenDelay
        closeDelay = try c.decodeIfPresent(Double.self, forKey: .closeDelay) ?? d.closeDelay
        pausedMusicVisibleMinutes = try c.decodeIfPresent(Double.self, forKey: .pausedMusicVisibleMinutes) ?? d.pausedMusicVisibleMinutes
        musicBarCount = try c.decodeIfPresent(Int.self, forKey: .musicBarCount) ?? d.musicBarCount
        musicBarSpeed = try c.decodeIfPresent(Double.self, forKey: .musicBarSpeed) ?? d.musicBarSpeed
        musicBarsUseArtworkColor = try c.decodeIfPresent(Bool.self, forKey: .musicBarsUseArtworkColor) ?? d.musicBarsUseArtworkColor
        marqueeEnabled = try c.decodeIfPresent(Bool.self, forKey: .marqueeEnabled) ?? d.marqueeEnabled
        closedWingWidth = try c.decodeIfPresent(Double.self, forKey: .closedWingWidth) ?? d.closedWingWidth
        animations = try c.decodeIfPresent(AnimationSettings.self, forKey: .animations) ?? d.animations
        openWidth = try c.decodeIfPresent(Double.self, forKey: .openWidth) ?? d.openWidth
        openHeight = try c.decodeIfPresent(Double.self, forKey: .openHeight) ?? d.openHeight
        showDebugOverlay = try c.decodeIfPresent(Bool.self, forKey: .showDebugOverlay) ?? d.showDebugOverlay
    }
}
