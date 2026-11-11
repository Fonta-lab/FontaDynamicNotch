import SwiftUI
import AppKit

/// An sRGB colour that can be saved in JSON.
struct CodableColor: Codable, Equatable, Sendable {
    var r: Double, g: Double, b: Double, a: Double = 1

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// From a colour picked in a ColorPicker.
    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(r: Double(ns.redComponent), g: Double(ns.greenComponent), b: Double(ns.blueComponent), a: Double(ns.alphaComponent))
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        r = (try? c.decode(Double.self, forKey: .r)) ?? 1
        g = (try? c.decode(Double.self, forKey: .g)) ?? 1
        b = (try? c.decode(Double.self, forKey: .b)) ?? 1
        a = (try? c.decode(Double.self, forKey: .a)) ?? 1
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    static func white(_ a: Double = 1) -> CodableColor { CodableColor(r: 1, g: 1, b: 1, a: a) }
    static let black = CodableColor(r: 0, g: 0, b: 0)
}

enum KnobShape: String, Codable, CaseIterable, Sendable { case circle, capsule, none }
enum SliderFillStyle: String, Codable, CaseIterable, Sendable { case solid, artwork }

/// A visual theme (SPEC §10.2). "Default" is built in and read-only; user themes are saved as
/// themes/<id>.json. Every key decodes with a default, so old or hand-edited files still load.
struct Theme: Codable, Equatable, Identifiable, Sendable {
    static let defaultID = "default"

    var id: String = Theme.defaultID
    var name: String = "Default"

    // Colours
    var fallbackBackgroundColor = CodableColor.black
    var primaryTextColor = CodableColor.white()
    var secondaryTextColor = CodableColor.white(0.6)
    var accentColor = CodableColor.white()
    var iconTint = CodableColor.white()
    var sliderTrackColor = CodableColor.white(0.2)
    var sliderFillColor = CodableColor.white()
    var sliderKnobColor = CodableColor.white()
    var useArtworkColor = true
    var artworkIntensity: Double = 1.0
    /// Brightest the artwork background may get (relative luminance). 0.183 keeps white text at 4.5:1.
    var maxBackgroundLuminance: Double = 0.183

    // Corner rounding
    var topFilletRadius: CGFloat = 12
    var openBottomRadius: CGFloat = 24
    var closedBottomRadius: CGFloat = 10
    var coverRadiusOpen: CGFloat = 12
    var coverRadiusClosed: CGFloat = 5
    var buttonRadius: CGFloat = 8

    // Shadow (open state only)
    var shadowEnabled = true
    var shadowTint = CodableColor.black
    var shadowOpacity: Double = 0.35
    var shadowRadius: CGFloat = 12
    var shadowYOffset: CGFloat = 4

    // Icon sizes
    var topBarIconSize: CGFloat = 12
    var controlIconSize: CGFloat = 16

    // Sliders
    var sliderHeight: CGFloat = 4
    var knobSize: CGFloat = 10
    var knobShape: KnobShape = .circle
    var knobOnlyOnHover = true
    var sliderFillStyle: SliderFillStyle = .solid

    static let `default` = Theme()

    var isBuiltIn: Bool { id == Theme.defaultID }

    // Convenience colours for views
    var fallbackBackground: Color { fallbackBackgroundColor.color }
    var primaryText: Color { primaryTextColor.color }
    var secondaryText: Color { secondaryTextColor.color }
    var accent: Color { accentColor.color }
    var iconColor: Color { iconTint.color }
    var sliderTrack: Color { sliderTrackColor.color }
    var sliderFill: Color { sliderFillColor.color }
    var sliderKnob: Color { sliderKnobColor.color }
    var shadowColor: Color { shadowTint.color }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Theme()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decode(T.self, forKey: key)) ?? fallback }
        id = v(.id, UUID().uuidString)
        name = v(.name, "Imported theme")
        fallbackBackgroundColor = v(.fallbackBackgroundColor, d.fallbackBackgroundColor)
        primaryTextColor = v(.primaryTextColor, d.primaryTextColor)
        secondaryTextColor = v(.secondaryTextColor, d.secondaryTextColor)
        accentColor = v(.accentColor, d.accentColor)
        iconTint = v(.iconTint, d.iconTint)
        sliderTrackColor = v(.sliderTrackColor, d.sliderTrackColor)
        sliderFillColor = v(.sliderFillColor, d.sliderFillColor)
        sliderKnobColor = v(.sliderKnobColor, d.sliderKnobColor)
        useArtworkColor = v(.useArtworkColor, d.useArtworkColor)
        artworkIntensity = v(.artworkIntensity, d.artworkIntensity)
        maxBackgroundLuminance = v(.maxBackgroundLuminance, d.maxBackgroundLuminance)
        topFilletRadius = v(.topFilletRadius, d.topFilletRadius)
        openBottomRadius = v(.openBottomRadius, d.openBottomRadius)
        closedBottomRadius = v(.closedBottomRadius, d.closedBottomRadius)
        coverRadiusOpen = v(.coverRadiusOpen, d.coverRadiusOpen)
        coverRadiusClosed = v(.coverRadiusClosed, d.coverRadiusClosed)
        buttonRadius = v(.buttonRadius, d.buttonRadius)
        shadowEnabled = v(.shadowEnabled, d.shadowEnabled)
        shadowTint = v(.shadowTint, d.shadowTint)
        shadowOpacity = v(.shadowOpacity, d.shadowOpacity)
        shadowRadius = v(.shadowRadius, d.shadowRadius)
        shadowYOffset = v(.shadowYOffset, d.shadowYOffset)
        topBarIconSize = v(.topBarIconSize, d.topBarIconSize)
        controlIconSize = v(.controlIconSize, d.controlIconSize)
        sliderHeight = v(.sliderHeight, d.sliderHeight)
        knobSize = v(.knobSize, d.knobSize)
        knobShape = v(.knobShape, d.knobShape)
        knobOnlyOnHover = v(.knobOnlyOnHover, d.knobOnlyOnHover)
        sliderFillStyle = v(.sliderFillStyle, d.sliderFillStyle)
    }
}
