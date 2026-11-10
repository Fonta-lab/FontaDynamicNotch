import Foundation
import Observation

/// A named counter (SPEC §7.3). Values can go negative.
struct CounterItem: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var value: Int

    init(id: UUID = UUID(), name: String, value: Int = 0) {
        self.id = id
        self.name = name
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decode(String.self, forKey: .name)) ?? "Counter"
        value = (try? c.decode(Int.self, forKey: .value)) ?? 0
    }
}

/// The counters. At least one always exists. Create / rename / delete / reorder come in Settings (M9).
@MainActor @Observable
final class CounterStore {
    static let shared = CounterStore()

    private(set) var counters: [CounterItem] = [CounterItem(name: "Counter")]
    private(set) var selectedID: UUID?

    private init() {}

    var selected: CounterItem? { counters.first { $0.id == selectedID } ?? counters.first }

    func restore(_ items: [CounterItem], selectedID: UUID?) {
        counters = items.isEmpty ? [CounterItem(name: "Counter")] : items
        self.selectedID = selectedID ?? counters.first?.id
    }

    func add(_ delta: Int) {
        guard let id = selected?.id, let i = counters.firstIndex(where: { $0.id == id }) else { return }
        counters[i].value &+= delta
        StateStore.shared.markDirty()
    }

    func reset() {
        guard let id = selected?.id, let i = counters.firstIndex(where: { $0.id == id }) else { return }
        counters[i].value = 0
        StateStore.shared.markDirty()
    }

    /// ‹ › arrows: previous / next counter, wrapping around.
    func step(_ direction: Int) {
        guard counters.count > 1, let id = selected?.id, let i = counters.firstIndex(where: { $0.id == id }) else { return }
        selectedID = counters[(i + direction + counters.count) % counters.count].id
        StateStore.shared.markDirty()
    }
}
