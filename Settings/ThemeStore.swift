import Foundation
import Observation

/// The built-in Default theme plus the user's themes (one JSON file each in themes/).
/// The selected theme applies live to every notch.
@MainActor @Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private(set) var userThemes: [Theme] = []
    @ObservationIgnored private var saveTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    nonisolated static var folder: URL { JSONFile.folder.appendingPathComponent("themes", isDirectory: true) }

    var all: [Theme] { [Theme.default] + userThemes }

    /// The theme the notch uses right now.
    var current: Theme {
        let id = SettingsStore.shared.settings.selectedThemeID
        return userThemes.first { $0.id == id } ?? .default
    }

    func load() async {
        let themes = await Task.detached(priority: .userInitiated) { () -> [Theme] in
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil) else { return [] }
            return files.filter { $0.pathExtension == "json" }.compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(Theme.self, from: data)
            }
        }.value
        userThemes = themes.filter { !$0.isBuiltIn }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: Editing

    /// Creates a copy of a theme (the way to "edit" the read-only Default) and selects it.
    @discardableResult
    func duplicate(_ theme: Theme) -> Theme {
        var t = theme
        t.id = UUID().uuidString
        t.name = uniqueName(theme.isBuiltIn ? "My theme" : "\(theme.name) copy")
        userThemes.append(t)
        save(t)
        SettingsStore.shared.settings.selectedThemeID = t.id
        return t
    }

    func update(_ theme: Theme) {
        guard !theme.isBuiltIn, let i = userThemes.firstIndex(where: { $0.id == theme.id }) else { return }
        guard userThemes[i] != theme else { return }
        userThemes[i] = theme
        save(theme)
    }

    func delete(_ id: String) {
        guard let i = userThemes.firstIndex(where: { $0.id == id }) else { return }
        userThemes.remove(at: i)
        if SettingsStore.shared.settings.selectedThemeID == id {
            SettingsStore.shared.settings.selectedThemeID = Theme.defaultID
        }
        let url = Self.folder.appendingPathComponent("\(id).json")
        Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: Import / export

    /// Adds a theme from a JSON file (missing keys get defaults; it always gets a new id).
    func importTheme(from url: URL) async -> Bool {
        let decoded = await Task.detached(priority: .userInitiated) { () -> Theme? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Theme.self, from: data)
        }.value
        guard var t = decoded else { return false }
        t.id = UUID().uuidString
        t.name = uniqueName(t.name.isEmpty ? "Imported theme" : t.name)
        userThemes.append(t)
        save(t)
        SettingsStore.shared.settings.selectedThemeID = t.id
        return true
    }

    func export(_ theme: Theme, to url: URL) {
        Task.detached(priority: .utility) {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? enc.encode(theme) { try? data.write(to: url, options: .atomic) }
        }
    }

    // MARK: Private

    private func uniqueName(_ base: String) -> String {
        let names = Set(all.map(\.name))
        if !names.contains(base) { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    /// Debounced per theme (sliders change values many times a second).
    private func save(_ theme: Theme) {
        saveTasks[theme.id]?.cancel()
        saveTasks[theme.id] = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let url = Self.folder.appendingPathComponent("\(theme.id).json")
            await Task.detached(priority: .utility) {
                let enc = JSONEncoder()
                enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                guard let data = try? enc.encode(theme) else { return }
                try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
                try? data.write(to: url, options: .atomic)
            }.value
        }
    }
}
