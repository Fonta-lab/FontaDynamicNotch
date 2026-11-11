import Foundation
import Observation

/// The built-in Default theme plus the user's themes (one JSON file each in themes/).
/// The built-in theme can be edited in place: the edited copy is saved as themes/<built-in id>.json
/// and "Reset" brings back the original. The selected theme applies live to every notch.
@MainActor @Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private(set) var userThemes: [Theme] = []
    /// Edited versions of the built-in themes, by id.
    private(set) var builtInEdits: [String: Theme] = [:]
    @ObservationIgnored private var saveTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    nonisolated static var folder: URL { JSONFile.folder.appendingPathComponent("themes", isDirectory: true) }

    /// Built-in themes with the user's edits applied.
    var builtIns: [Theme] { Theme.builtIns.map { builtInEdits[$0.id] ?? $0 } }

    var all: [Theme] { builtIns + userThemes }

    /// The theme the notch uses right now.
    var current: Theme {
        let id = SettingsStore.shared.settings.selectedThemeID
        return builtIns.first { $0.id == id } ?? userThemes.first { $0.id == id } ?? builtIns[0]
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
        builtInEdits = Dictionary(themes.filter(\.isBuiltIn).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        userThemes = themes.filter { !$0.isBuiltIn }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: Editing

    /// Creates a copy of a theme and selects it.
    @discardableResult
    func duplicate(_ theme: Theme) -> Theme {
        var t = theme
        t.id = UUID().uuidString
        t.name = uniqueName(theme.id == Theme.defaultID ? "My theme" : "\(theme.name) copy")
        userThemes.append(t)
        save(t)
        SettingsStore.shared.settings.selectedThemeID = t.id
        return t
    }

    func update(_ theme: Theme) {
        if theme.isBuiltIn {
            guard builtIns.first(where: { $0.id == theme.id }) != theme else { return }
            builtInEdits[theme.id] = theme
            save(theme)
            return
        }
        guard let i = userThemes.firstIndex(where: { $0.id == theme.id }) else { return }
        guard userThemes[i] != theme else { return }
        userThemes[i] = theme
        save(theme)
    }

    /// True if a built-in theme was edited.
    func isEdited(_ id: String) -> Bool {
        guard let edit = builtInEdits[id] else { return false }
        return Theme.builtIns.first { $0.id == id } != edit
    }

    /// Brings a built-in theme back to its original values.
    func resetBuiltIn(_ id: String) {
        guard builtInEdits.removeValue(forKey: id) != nil else { return }
        saveTasks[id]?.cancel()
        let url = Self.folder.appendingPathComponent("\(id).json")
        Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: url) }
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
