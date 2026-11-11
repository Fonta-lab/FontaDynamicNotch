import Foundation

/// Alarm sounds: the macOS ones and those the user imported (copied into sounds/).
enum SoundLibrary {
    static var customFolder: URL { JSONFile.folder.appendingPathComponent("sounds", isDirectory: true) }
    private static let audioExtensions: Set<String> = ["aiff", "aif", "wav", "mp3", "m4a", "caf", "aac"]

    /// Lists both folders. Call off the main thread.
    static func list() -> [AlarmSoundRef] {
        let fm = FileManager.default
        func files(_ dir: URL) -> [String] {
            ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
                .filter { audioExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }
        return files(URL(fileURLWithPath: "/System/Library/Sounds")).map { AlarmSoundRef(isCustom: false, fileName: $0) }
            + files(customFolder).map { AlarmSoundRef(isCustom: true, fileName: $0) }
    }

    /// Copies a user's audio file into sounds/ and returns its reference. Call off the main thread.
    static func importSound(from url: URL) -> AlarmSoundRef? {
        let fm = FileManager.default
        try? fm.createDirectory(at: customFolder, withIntermediateDirectories: true)
        var name = url.lastPathComponent
        var dest = customFolder.appendingPathComponent(name)
        var n = 2
        while fm.fileExists(atPath: dest.path) {
            name = "\(url.deletingPathExtension().lastPathComponent) \(n).\(url.pathExtension)"
            dest = customFolder.appendingPathComponent(name)
            n += 1
        }
        guard (try? fm.copyItem(at: url, to: dest)) != nil else { return nil }
        return AlarmSoundRef(isCustom: true, fileName: name)
    }
}

/// Plays a sound once for the Settings "Preview" button.
@MainActor
final class SoundPreview {
    static let shared = SoundPreview()
    private let player = AlarmPlayer()
    private init() {}

    func play(_ sound: AlarmSoundRef, volume: Double) {
        player.start(url: sound.url, volume: Float(volume), loop: false) { _ in }
    }

    func stop() { player.stop() }
}
