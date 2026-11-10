import SwiftUI

/// Stopwatch tool (SPEC §7.2): time as mm:ss.cc, last lap underneath, hover the time for all laps.
/// Redraws at most 30×/s, and only while this panel is visible and running.
struct StopwatchPanelView: View {
    let theme: Theme
    private var store: StopwatchStore { .shared }
    @State private var showLaps = false

    var body: some View {
        let laps = store.lapDurations
        VStack(spacing: 4) {
            Text("Stopwatch")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondaryText)
            Spacer(minLength: 0)
            ZStack {
                VStack(spacing: 2) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !store.isRunning)) { ctx in
                        Text(StopwatchFormat.precise(store.elapsed(at: ctx.date)))
                            .font(.system(size: 26, weight: .semibold).monospacedDigit())
                            .foregroundStyle(theme.primaryText.opacity(store.isRunning || store.isIdle ? 1 : 0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text(laps.last.map { "Lap \(laps.count)  \(StopwatchFormat.precise($0))" } ?? " ")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(theme.secondaryText)
                }
                .opacity(showLaps ? 0 : 1)

                if showLaps { lapList(laps) }
            }
            .frame(height: 48)
            .contentShape(Rectangle())
            .onHover { showLaps = $0 && !laps.isEmpty }
            .animation(.easeOut(duration: 0.15), value: showLaps)
            Spacer(minLength: 0)
            controls
        }
    }

    private func lapList(_ laps: [TimeInterval]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 1) {
                ForEach(Array(laps.enumerated().reversed()), id: \.offset) { i, d in
                    HStack {
                        Text("Lap \(i + 1)")
                        Spacer()
                        Text(StopwatchFormat.precise(d))
                    }
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.primaryText)
                }
            }
            .padding(.horizontal, 6)
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Button { store.toggle() } label: {
                Label(store.isRunning ? "Pause" : (store.isIdle ? "Start" : "Resume"),
                      systemImage: store.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, filled: true))

            iconButton("flag.fill", help: "Lap", enabled: store.isRunning) { store.lap() }
            iconButton("arrow.counterclockwise", help: "Reset", enabled: !store.isIdle) { store.reset() }
        }
    }

    private func iconButton(_ symbol: String, help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.primaryText.opacity(enabled ? 1 : 0.35))
                .frame(width: 30, height: 24)
        }
        .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, filled: true))
        .disabled(!enabled)
        .help(help)
    }
}
