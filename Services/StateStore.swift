import Foundation

/// Loads and saves state.json (timers, stopwatch, counters, last tool).
/// Saves are debounced 0.5 s and written off the main thread; also written on quit and before sleep.
@MainActor
final class StateStore {
    static let shared = StateStore()
    nonisolated private static let fileName = "state.json"

    private var saveTask: Task<Void, Never>?
    private var loaded = false

    private init() {}

    /// Reads state.json off-main and hands it to the stores.
    func load() async {
        let state = await Task.detached(priority: .userInitiated) {
            JSONFile.read(PersistedState.self, name: Self.fileName) ?? PersistedState()
        }.value
        // Mark loaded first, so changes made while restoring (missed timers reset to idle) get saved.
        loaded = true
        ToolState.shared.restore(state.lastTool)
        StopwatchStore.shared.restore(state.stopwatch)
        CounterStore.shared.restore(state.counters, selectedID: state.selectedCounterID)
        TimerStore.shared.restore(state.timerList, selectedID: state.selectedTimerID)
    }

    func markDirty() {
        guard loaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let snap = snapshot()
            await Task.detached(priority: .utility) { JSONFile.write(snap, name: Self.fileName) }.value
        }
    }

    /// Immediate write (quit, sleep).
    func flush() {
        guard loaded else { return }
        saveTask?.cancel()
        JSONFile.write(snapshot(), name: Self.fileName)
    }

    private func snapshot() -> PersistedState {
        var s = PersistedState()
        s.timerList = TimerStore.shared.timers
        s.selectedTimerID = TimerStore.shared.selectedID
        s.stopwatch = StopwatchStore.shared.state
        s.counters = CounterStore.shared.counters
        s.selectedCounterID = CounterStore.shared.selectedID
        s.lastTool = ToolState.shared.lastUsed
        return s
    }
}
