import SwiftUI

/// One spring, stored in "advanced" form (response / damping / blend). M9 adds the simple duration/bounce editor.
struct SpringSetting: Codable, Equatable, Sendable {
    var response: Double
    var dampingFraction: Double
    var blendDuration: Double = 0

    init(response: Double, dampingFraction: Double, blendDuration: Double = 0) {
        self.response = response
        self.dampingFraction = dampingFraction
        self.blendDuration = blendDuration
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        response = try c.decodeIfPresent(Double.self, forKey: .response) ?? 0.4
        dampingFraction = try c.decodeIfPresent(Double.self, forKey: .dampingFraction) ?? 0.8
        blendDuration = try c.decodeIfPresent(Double.self, forKey: .blendDuration) ?? 0
    }

    /// The spring, or a short fade when Reduce Motion is on.
    var animation: Animation {
        if Motion.reduceMotion { return Motion.reducedFade }
        return .spring(response: response, dampingFraction: dampingFraction, blendDuration: blendDuration)
    }
}

/// The separate springs from SPEC §9. Defaults are [Guess] starting values.
struct AnimationSettings: Codable, Equatable, Sendable {
    var open = SpringSetting(response: 0.42, dampingFraction: 0.78)
    var close = SpringSetting(response: 0.35, dampingFraction: 0.90)
    var wings = SpringSetting(response: 0.40, dampingFraction: 0.80)
    var brightness = SpringSetting(response: 0.30, dampingFraction: 0.85)
    var tabSwitch = SpringSetting(response: 0.35, dampingFraction: 0.90)
    var alarmOpen = SpringSetting(response: 0.45, dampingFraction: 0.70)

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AnimationSettings()
        open = try c.decodeIfPresent(SpringSetting.self, forKey: .open) ?? d.open
        close = try c.decodeIfPresent(SpringSetting.self, forKey: .close) ?? d.close
        wings = try c.decodeIfPresent(SpringSetting.self, forKey: .wings) ?? d.wings
        brightness = try c.decodeIfPresent(SpringSetting.self, forKey: .brightness) ?? d.brightness
        tabSwitch = try c.decodeIfPresent(SpringSetting.self, forKey: .tabSwitch) ?? d.tabSwitch
        alarmOpen = try c.decodeIfPresent(SpringSetting.self, forKey: .alarmOpen) ?? d.alarmOpen
    }
}
