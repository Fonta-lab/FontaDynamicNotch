import AppKit
import Observation
import QuickLookThumbnailing

/// A file on the shelf. Only a reference (the file stays where it is). Not saved: the shelf
/// empties when the app quits (SPEC §8).
struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var thumbnail: NSImage?

    var name: String { url.lastPathComponent }
}

@MainActor @Observable
final class ShelfStore {
    static let shared = ShelfStore()

    private(set) var items: [ShelfItem] = []
    var selection: Set<ShelfItem.ID> = []

    private init() {}

    var selectedURLs: [URL] { items.filter { selection.contains($0.id) }.map(\.url) }

    func add(_ urls: [URL]) {
        let existing = Set(items.map { $0.url.standardizedFileURL })
        for url in urls where url.isFileURL && !existing.contains(url.standardizedFileURL) {
            let item = ShelfItem(url: url, thumbnail: nil)
            items.append(item)
            loadThumbnail(for: item)
        }
    }

    func remove(_ id: ShelfItem.ID) {
        items.removeAll { $0.id == id }
        selection.remove(id)
    }

    func clear() {
        items.removeAll()
        selection.removeAll()
    }

    func toggleSelection(_ id: ShelfItem.ID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    // MARK: AirDrop

    /// Opens the system AirDrop sheet for these files. Returns false if AirDrop isn't available.
    @discardableResult
    func airDrop(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else { return false }
        service.perform(withItems: urls)
        return true
    }

    // MARK: Trash

    /// Moves files to the Trash right away (no confirmation, no undo — user's choice). Runs off the
    /// main thread. Returns the names that failed (e.g. on a read-only or network volume).
    func trash(_ urls: [URL]) async -> [String] {
        let results = await Task.detached(priority: .userInitiated) { () -> [(URL, Bool)] in
            urls.map { url in
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    return (url, true)
                } catch {
                    return (url, false)
                }
            }
        }.value
        let trashed = Set(results.filter(\.1).map { $0.0.standardizedFileURL })
        let removedIDs = items.filter { trashed.contains($0.url.standardizedFileURL) }.map(\.id)
        items.removeAll { removedIDs.contains($0.id) }
        removedIDs.forEach { selection.remove($0) }
        return results.filter { !$0.1 }.map { $0.0.lastPathComponent }
    }

    // MARK: Thumbnails

    private func loadThumbnail(for item: ShelfItem) {
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: 96, height: 96),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2,
                                                   representationTypes: .all)
        let id = item.id
        Task {
            let image: NSImage
            if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                image = rep.nsImage
            } else {
                image = NSWorkspace.shared.icon(forFile: item.url.path)
            }
            if let i = items.firstIndex(where: { $0.id == id }) { items[i].thumbnail = image }
        }
    }
}
