import Foundation
import Observation

/// Holds the live settings. Loads and saves `settings.json` off the main thread (debounced 0.5 s).
@MainActor @Observable
final class SettingsStore {
    static let shared = SettingsStore()

    var settings = AppSettings() {
        didSet { if settings != oldValue { scheduleSave() } }
    }

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var loaded = false

    nonisolated static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FontaDynamicNotch", isDirectory: true)
    }
    nonisolated private static var fileURL: URL { folder.appendingPathComponent("settings.json") }

    private init() {}

    /// Reads settings.json on a background thread, then applies it.
    func load() async {
        let loadedSettings = await Task.detached(priority: .userInitiated) { () -> AppSettings in
            guard let data = try? Data(contentsOf: Self.fileURL),
                  let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
            return s
        }.value
        loaded = true
        settings = loadedSettings
    }

    private func scheduleSave() {
        guard loaded else { return }
        saveTask?.cancel()
        let snapshot = settings
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) { Self.write(snapshot) }.value
        }
    }

    /// Writes immediately (used on quit).
    func flush() {
        guard loaded else { return }
        saveTask?.cancel()
        Self.write(settings)
    }

    nonisolated private static func write(_ s: AppSettings) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(s) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
