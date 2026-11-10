import Foundation
import Observation

/// Stopwatch state (SPEC §7.2). Wall-clock based, so it keeps counting while the Mac is off.
enum StopwatchRun: Codable, Equatable, Sendable {
    case idle
    case running(startDate: Date, accumulated: TimeInterval)
    case paused(accumulated: TimeInterval)
}

struct StopwatchState: Codable, Equatable, Sendable {
    var run: StopwatchRun = .idle
    /// Elapsed time at each lap press (cumulative).
    var laps: [TimeInterval] = []

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        run = (try? c.decode(StopwatchRun.self, forKey: .run)) ?? .idle
        laps = (try? c.decode([TimeInterval].self, forKey: .laps)) ?? []
    }
}

/// The one stopwatch. No ticking of its own: views compute the time when they draw.
@MainActor @Observable
final class StopwatchStore {
    static let shared = StopwatchStore()

    private(set) var state = StopwatchState()

    private init() {}

    var isRunning: Bool { if case .running = state.run { true } else { false } }
    var isIdle: Bool { state.run == .idle }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        switch state.run {
        case .idle: 0
        case .running(let start, let acc): acc + max(0, date.timeIntervalSince(start))
        case .paused(let acc): acc
        }
    }

    /// Lap durations (each lap minus the previous one), oldest first.
    var lapDurations: [TimeInterval] {
        zip(state.laps, [0] + state.laps).map { $0 - $1 }
    }

    func restore(_ s: StopwatchState) { state = s }

    func toggle() {
        switch state.run {
        case .idle: state.run = .running(startDate: Date(), accumulated: 0)
        case .paused(let acc): state.run = .running(startDate: Date(), accumulated: acc)
        case .running: state.run = .paused(accumulated: elapsed())
        }
        changed()
    }

    func lap() {
        guard isRunning else { return }
        state.laps.append(elapsed())
        changed()
    }

    /// Clears everything, laps included (no lap history is kept).
    func reset() {
        state = StopwatchState()
        changed()
    }

    private func changed() { StateStore.shared.markDirty() }
}

enum StopwatchFormat {
    /// mm:ss.cc, or h:mm:ss.cc after an hour.
    static func precise(_ t: TimeInterval) -> String {
        let cs = Int((max(0, t) * 100).rounded(.down))
        let h = cs / 360_000, m = cs / 6000 % 60, s = cs / 100 % 60, c = cs % 100
        return h > 0 ? String(format: "%d:%02d:%02d.%02d", h, m, s, c) : String(format: "%02d:%02d.%02d", m, s, c)
    }

    /// Closed-notch format: no centiseconds.
    static func coarse(_ t: TimeInterval) -> String { TimeFormat.clock(t.rounded(.down)) }
}
