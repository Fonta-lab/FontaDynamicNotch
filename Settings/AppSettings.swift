import Foundation

/// A button in the open notch's top bar (SPEC §10.3).
enum TopModule: String, Codable, CaseIterable, Identifiable, Sendable {
    case homeFiles, screenBrightness, keyboardBrightness, timer, stopwatch, counter
    var id: String { rawValue }

    var title: String {
        switch self {
        case .homeFiles: "Home / Files"
        case .screenBrightness: "Screen brightness"
        case .keyboardBrightness: "Keyboard brightness"
        case .timer: "Timer"
        case .stopwatch: "Stopwatch"
        case .counter: "Counter"
        }
    }

    var symbol: String {
        switch self {
        case .homeFiles: "house.fill"
        case .screenBrightness: "sun.max.fill"
        case .keyboardBrightness: "light.max"
        case .timer: "timer"
        case .stopwatch: "stopwatch"
        case .counter: "plusminus"
        }
    }

    var tool: Tool? {
        switch self {
        case .timer: .timer
        case .stopwatch: .stopwatch
        case .counter: .counter
        default: nil
        }
    }

    static let defaultLeft: [TopModule] = [.homeFiles, .screenBrightness, .keyboardBrightness]
    static let defaultRight: [TopModule] = [.timer, .stopwatch, .counter]
}

/// Which alarm sound plays: a macOS sound or one the user imported (copied into sounds/).
struct AlarmSoundRef: Codable, Equatable, Hashable, Sendable {
    var isCustom = false
    var fileName = "Glass.aiff"

    var displayName: String { (fileName as NSString).deletingPathExtension }

    var url: URL {
        isCustom ? JSONFile.folder.appendingPathComponent("sounds").appendingPathComponent(fileName)
                 : URL(fileURLWithPath: "/System/Library/Sounds").appendingPathComponent(fileName)
    }

    init(isCustom: Bool = false, fileName: String = "Glass.aiff") {
        self.isCustom = isCustom
        self.fileName = fileName
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isCustom = (try? c.decode(Bool.self, forKey: .isCustom)) ?? false
        fileName = (try? c.decode(String.self, forKey: .fileName)) ?? "Glass.aiff"
    }
}

/// All user settings. Every key decodes on its own with a default, so adding settings later — or a
/// bad value in one key — never wipes the rest of the file.
struct AppSettings: Codable, Equatable, Sendable {
    var schemaVersion = 1
    // General
    var notchOnAllScreens = true
    var showFakeNotchWhenIdle = true
    var showMenuBarIcon = true
    var hoverOpenDelay: Double = 0.10
    var closeDelay: Double = 0
    var pausedMusicVisibleMinutes: Double = 10
    // Appearance
    var selectedThemeID = Theme.defaultID
    // Music
    var musicBarCount = 4
    var musicBarSpeed: Double = 0.3
    var musicBarsUseArtworkColor = true
    var marqueeEnabled = true
    // Timers
    var alarmSound = AlarmSoundRef()
    var alarmVolume: Double = 1.0
    // Animations
    var animations = AnimationSettings()
    var springEditorAdvanced = false
    // Layout & modules
    var leftModules = TopModule.defaultLeft
    var rightModules = TopModule.defaultRight
    var hiddenModules: [TopModule] = []
    var openWidth: Double = 604
    var openHeight: Double = 176
    var closedWingWidth: Double = 39
    /// Extra height for the closed shape, because the physical notch hangs a bit below what macOS reports.
    var closedHeightExtra: Double = 0
    // Advanced
    var showDebugOverlay = false

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decode(T.self, forKey: key)) ?? fallback }
        schemaVersion = v(.schemaVersion, d.schemaVersion)
        notchOnAllScreens = v(.notchOnAllScreens, d.notchOnAllScreens)
        showFakeNotchWhenIdle = v(.showFakeNotchWhenIdle, d.showFakeNotchWhenIdle)
        showMenuBarIcon = v(.showMenuBarIcon, d.showMenuBarIcon)
        hoverOpenDelay = v(.hoverOpenDelay, d.hoverOpenDelay)
        closeDelay = v(.closeDelay, d.closeDelay)
        pausedMusicVisibleMinutes = v(.pausedMusicVisibleMinutes, d.pausedMusicVisibleMinutes)
        selectedThemeID = v(.selectedThemeID, d.selectedThemeID)
        musicBarCount = v(.musicBarCount, d.musicBarCount)
        musicBarSpeed = v(.musicBarSpeed, d.musicBarSpeed)
        musicBarsUseArtworkColor = v(.musicBarsUseArtworkColor, d.musicBarsUseArtworkColor)
        marqueeEnabled = v(.marqueeEnabled, d.marqueeEnabled)
        alarmSound = v(.alarmSound, d.alarmSound)
        alarmVolume = v(.alarmVolume, d.alarmVolume)
        animations = v(.animations, d.animations)
        springEditorAdvanced = v(.springEditorAdvanced, d.springEditorAdvanced)
        leftModules = Self.cleaned(v(.leftModules, d.leftModules), allowed: TopModule.defaultLeft)
        rightModules = Self.cleaned(v(.rightModules, d.rightModules), allowed: TopModule.defaultRight)
        hiddenModules = v(.hiddenModules, d.hiddenModules)
        openWidth = v(.openWidth, d.openWidth)
        openHeight = v(.openHeight, d.openHeight)
        closedWingWidth = v(.closedWingWidth, d.closedWingWidth)
        closedHeightExtra = v(.closedHeightExtra, d.closedHeightExtra)
        showDebugOverlay = v(.showDebugOverlay, d.showDebugOverlay)
    }

    /// Keeps a saved order valid: no duplicates, nothing from the other group, nothing missing.
    private static func cleaned(_ list: [TopModule], allowed: [TopModule]) -> [TopModule] {
        var seen = Set<TopModule>()
        let kept = list.filter { allowed.contains($0) && seen.insert($0).inserted }
        return kept + allowed.filter { !seen.contains($0) }
    }

    func isVisible(_ m: TopModule) -> Bool { !hiddenModules.contains(m) }

    /// Tools in the user's order, without hidden ones.
    var visibleTools: [Tool] { rightModules.filter(isVisible).compactMap(\.tool) }
}
