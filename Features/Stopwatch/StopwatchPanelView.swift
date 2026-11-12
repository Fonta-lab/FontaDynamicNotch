import SwiftUI

/// Stopwatch tool (SPEC §7.2): time as mm:ss.cc, last lap underneath, hover the time for all laps.
/// Redraws at most 30×/s, and only while this panel is visible and running.
struct StopwatchPanelView: View {
    let theme: Theme
    private var store: StopwatchStore { .shared }
    @State private var showLaps = false

    var body: some View {
        let laps = store.lapDurations
        VStack(spacing: Spacing.xs) {
            Text("Stopwatch")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.secondaryText)
            Spacer(minLength: 0)
            ZStack {
                VStack(spacing: Spacing.xxs) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !store.isRunning)) { ctx in
                        Text(StopwatchFormat.precise(store.elapsed(at: ctx.date)))
                            .font(ToolPanelStyle.valueFont)
                            .foregroundStyle(theme.primaryText.opacity(store.isRunning || store.isIdle ? 1 : 0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text(laps.last.map { "Lap \(laps.count)  \(StopwatchFormat.precise($0))" } ?? " ")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(theme.secondaryText)
                }
                .opacity(showLaps ? 0 : 1)

                if showLaps { lapList(laps) }
            }
            .frame(height: 40)
            .contentShape(Rectangle())
            .notchHover { showLaps = $0 && !laps.isEmpty }
            .animation(Motion.change, value: showLaps)
            Spacer(minLength: 0)
            controls
        }
    }

    private func lapList(_ laps: [TimeInterval]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(laps.enumerated().reversed()), id: \.offset) { i, d in
                    HStack {
                        Text("Lap \(i + 1)")
                        Spacer()
                        Text(StopwatchFormat.precise(d))
                    }
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(theme.primaryText)
                }
            }
            .padding(.horizontal, Spacing.s)
        }
        .background(RoundedRectangle(cornerRadius: theme.buttonRadius, style: .continuous).fill(Color.black.opacity(0.35)))
    }

    private var controls: some View {
        HStack(spacing: Spacing.s) {
            PanelButton(theme: theme, symbol: store.isRunning ? "pause.fill" : "play.fill",
                        help: store.isRunning ? "Pause" : (store.isIdle ? "Start" : "Resume")) { store.toggle() }
            PanelButton(theme: theme, symbol: "flag.fill", enabled: store.isRunning, help: "Lap") { store.lap() }
            PanelButton(theme: theme, symbol: "arrow.counterclockwise", enabled: !store.isIdle, help: "Reset") { store.reset() }
        }
    }
}
