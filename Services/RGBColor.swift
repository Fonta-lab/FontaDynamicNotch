import SwiftUI

/// A plain sRGB colour (0…1) that can cross threads.
struct RGBColor: Equatable, Sendable {
    var r: Double, g: Double, b: Double

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }

    /// WCAG relative luminance.
    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    var saturation: Double {
        let mx = max(r, g, b), mn = min(r, g, b)
        return mx == 0 ? 0 : (mx - mn) / mx
    }

    var brightness: Double { max(r, g, b) }

    func scaled(_ k: Double) -> RGBColor { RGBColor(r: r * k, g: g * k, b: b * k) }

    func mixed(with o: RGBColor, _ t: Double) -> RGBColor {
        RGBColor(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    /// Darkens until the colour is no brighter than `maxLuminance` (0.183 keeps white text at 4.5:1).
    func darkened(toMaxLuminance maxLum: Double) -> RGBColor {
        var c = self
        var i = 0
        while c.luminance > maxLum && i < 60 {
            c = c.scaled(0.95)
            i += 1
        }
        return c
    }

    /// A bright version for the closed-notch bars.
    var lightenedForBars: RGBColor {
        var c = self
        if c.brightness > 0 { c = c.scaled(0.95 / c.brightness) }   // push to full brightness
        return c.mixed(with: RGBColor(r: 1, g: 1, b: 1), 0.25)
    }

    static let white = RGBColor(r: 1, g: 1, b: 1)
}
