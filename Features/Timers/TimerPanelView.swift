import SwiftUI

/// Timer tool (SPEC §7.1): one timer. Starred lengths (up to 3) as chips on top, the time in the
/// middle (set in place while idle: ▲▼ on hover, or scroll), and Start/Pause, Reset and Star.
struct TimerPanelView: View {
    let theme: Theme
    private var store: TimerStore { .shared }
    @State private var toast: String?
    @State private var toastWork: DispatchWorkItem?

    var body: some View {
        let t = store.timer
        VStack(spacing: Spacing.xs) {
            chips(t)
            Spacer(minLength: 0)
            if t.isIdle {
                TimerDurationEditor(duration: t.duration, theme: theme)
            } else {
                // Refreshes only while this panel is visible and the timer runs.
                TimelineView(.animation(minimumInterval: 0.25, paused: !t.isRunning)) { ctx in
                    Text(TimeFormat.countdown(store.remaining(at: ctx.date)))
                        .font(ToolPanelStyle.valueFont)
                        .foregroundStyle(timeColor(t))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            Spacer(minLength: 0)
            controls(t)
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.s)
                    .frame(maxWidth: .infinity, minHeight: 20)   // covers the whole chip row
                    .background(Capsule().fill(Color.black.opacity(0.9)))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(Motion.change, value: toast)
    }

    // MARK: Starred chips

    /// Three equal slots, so chips don't change width as stars are added or removed.
    @ViewBuilder private func chips(_ t: TimerItem) -> some View {
        if store.starred.isEmpty {
            Label("Star a time to save it", systemImage: "star")
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 20)
        } else {
            HStack(spacing: Spacing.xs) {
                ForEach(0..<TimerStore.maxStars, id: \.self) { i in
                    if i < store.starred.count {
                        chip(store.starred[i], t)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: 20)
                    }
                }
            }
        }
    }

    private func chip(_ d: TimeInterval, _ t: TimerItem) -> some View {
        let isCurrent = d == t.duration
        return Button { store.setDuration(d) } label: {
            Text(TimeFormat.clock(d))
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .foregroundStyle(theme.primaryText.opacity(isCurrent ? 1 : 0.65))
                .frame(maxWidth: .infinity, minHeight: 20)
                .background(Capsule().fill(theme.primaryText.opacity(isCurrent ? Highlight.selected : Highlight.panel)))
                .overlay(alignment: .topTrailing) {
                    if isCurrent && (t.isRunning || t.isRinging) {
                        Circle().fill(t.isRinging ? Color.red : theme.accent)
                            .frame(width: 4, height: 4).offset(x: -Spacing.xs, y: Spacing.xxs)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!t.isIdle)   // the length can change only before Start (or after Reset)
        .opacity(t.isIdle || isCurrent ? 1 : 0.5)
        .help(t.isIdle ? "Set the timer to \(TimeFormat.label(d))" : "Reset the timer to pick another time")
        .accessibilityLabel(TimeFormat.label(d))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    // MARK: Controls

    private func controls(_ t: TimerItem) -> some View {
        let (help, symbol): (String, String) = switch t.run {
        case .running: ("Pause", "pause.fill")
        case .paused: ("Resume", "play.fill")
        default: ("Start", "play.fill")
        }
        let starred = store.isCurrentStarred
        return HStack(spacing: Spacing.s) {
            PanelButton(theme: theme, symbol: symbol, enabled: !t.isRinging, help: help) { store.toggle() }
            PanelButton(theme: theme, symbol: "arrow.counterclockwise", enabled: !t.isIdle, help: "Reset") { store.reset() }
            PanelButton(theme: theme, symbol: starred ? "star.fill" : "star",
                        help: starred ? "Remove this time from the starred ones" : "Star this time") {
                if store.toggleStar() == .full { showToast("\(TimerStore.maxStars) timers already saved") }
            }
        }
    }

    private func showToast(_ text: String) {
        toastWork?.cancel()
        toast = text
        let work = DispatchWorkItem { toast = nil }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private func timeColor(_ t: TimerItem) -> Color {
        switch t.run {
        case .paused: theme.primaryText.opacity(0.55)
        case .ringing: .red
        default: theme.primaryText
        }
    }
}

/// Shown instead of the Home tab while the alarm rings (SPEC §7.4): the timer's length and a big Stop.
struct AlarmView: View {
    let theme: Theme
    private var timers: TimerStore { .shared }

    var body: some View {
        HStack(spacing: Spacing.l) {
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                // Apple's own ringing effect: the waves light up in turn (calms down with Reduce Motion).
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Timer ended")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                Text(TimeFormat.label(timers.timer.duration))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { AlarmService.shared.stop() } label: {
                Text("Stop")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: 120, height: 52)
                    .background(Capsule().fill(Color.white))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.s)
    }
}
