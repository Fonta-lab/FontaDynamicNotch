import SwiftUI

/// Timer tool (SPEC §7.1). Chips on top: each is a timer (starred, or started) with its time or
/// live countdown, plus a + chip in the next free slot for a new timer; up to 3 run at once. The
/// middle shows the selected timer (set in place while idle: scroll or drag a number) with the
/// star on its right; below, Start/Pause and Reset.
struct TimerPanelView: View {
    let theme: Theme
    private var store: TimerStore { .shared }
    @State private var toast: String?
    @State private var toastWork: DispatchWorkItem?
    private static let chipHeight: CGFloat = 20

    var body: some View {
        let t = store.selected
        VStack(spacing: Spacing.xs) {
            chipRow(selected: t)
            Spacer(minLength: 0)
            // The star sits right of the time; an equal empty space on the left keeps the time centred.
            HStack(spacing: 0) {
                Color.clear.frame(width: StarButton.width, height: 1)
                time(t).frame(maxWidth: .infinity)
                StarButton(starred: t.starred, theme: theme) {
                    if store.toggleStar() == .full { showFullMessage() }
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
                    .frame(maxWidth: .infinity, minHeight: Self.chipHeight)   // covers the whole chip row
                    .background(Capsule().fill(Color.black.opacity(0.9)))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(Motion.change, value: toast)
    }

    // MARK: Chips

    /// Three equal slots: the timers, then a + in the next free slot.
    private func chipRow(selected: TimerItem) -> some View {
        let chips = store.chips
        let counting = chips.contains(where: \.isRunning)
        // Live countdowns on running chips: about twice a second, only while one runs.
        return TimelineView(.animation(minimumInterval: 0.5, paused: !counting)) { ctx in
            HStack(spacing: Spacing.xs) {
                ForEach(0..<TimerStore.maxChips, id: \.self) { i in
                    if i < chips.count {
                        chip(chips[i], isSelected: chips[i].id == selected.id, at: ctx.date)
                    } else if i == chips.count {
                        addChip(isSelected: !selected.isChip)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        // Fixed height: an empty slot must not stretch and push the time down.
        .frame(height: Self.chipHeight)
    }

    private func chip(_ t: TimerItem, isSelected: Bool, at date: Date) -> some View {
        let text = t.isIdle ? TimeFormat.clock(t.duration) : TimeFormat.countdown(store.remaining(t, at: date))
        return Button { store.select(t.id) } label: {
            Text(text)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .foregroundStyle(theme.primaryText.opacity(isSelected ? 1 : 0.65))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Capsule().fill(theme.primaryText.opacity(isSelected ? Highlight.selected : Highlight.panel)))
                .overlay(alignment: .topTrailing) {
                    if !t.isIdle {
                        // Running: accent dot. Paused: dimmed. Ringing: red.
                        Circle().fill(t.isRinging ? Color.red : theme.accent.opacity(t.isRunning ? 1 : 0.4))
                            .frame(width: 4, height: 4).offset(x: -Spacing.xs, y: Spacing.xxs)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(t.isIdle ? "\(TimeFormat.label(t.duration)) (starred)" : "\(TimeFormat.label(t.duration)) timer")
        .accessibilityLabel("\(TimeFormat.label(t.duration)) timer")
        .accessibilityValue(t.isRunning ? "Running" : t.isIdle ? "" : t.isRinging ? "Ended" : "Paused")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Same shape as the timer chips. Highlighted while the new timer is the one being set.
    private func addChip(isSelected: Bool) -> some View {
        Button { store.addTimer() } label: {
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.primaryText.opacity(isSelected ? 1 : 0.65))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Capsule().fill(theme.primaryText.opacity(isSelected ? Highlight.selected : Highlight.panel)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("New timer")
        .accessibilityLabel("New timer")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Controls

    private func controls(_ t: TimerItem) -> some View {
        let (help, symbol): (String, String) = switch t.run {
        case .running: ("Pause", "pause.fill")
        case .paused: ("Resume", "play.fill")
        default: ("Start", "play.fill")
        }
        return HStack(spacing: Spacing.s) {
            PanelButton(theme: theme, symbol: symbol, enabled: !t.isRinging, help: help) {
                if store.toggle() == .full { showFullMessage() }
            }
            PanelButton(theme: theme, symbol: "arrow.counterclockwise", enabled: !t.isIdle, help: "Reset") { store.reset() }
        }
    }

    /// The selected timer's time: editable while idle, a countdown otherwise.
    @ViewBuilder private func time(_ t: TimerItem) -> some View {
        if t.isIdle {
            // Very long times (10 h and more) step down to Title so they fit beside the star.
            ViewThatFits(in: .horizontal) {
                TimerDurationEditor(duration: t.duration, theme: theme)
                TimerDurationEditor(duration: t.duration, theme: theme,
                                    font: .title.weight(.semibold).monospacedDigit())
            }
        } else {
            // Refreshes only while this panel is visible and the timer runs.
            TimelineView(.animation(minimumInterval: 0.25, paused: !t.isRunning)) { ctx in
                Text(TimeFormat.countdown(store.remaining(t, at: ctx.date)))
                    .font(ToolPanelStyle.valueFont)
                    .foregroundStyle(timeColor(t))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func showFullMessage() {
        showToast("\(TimerStore.maxChips) timers already saved")
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

/// The star right of the time: just the symbol, no box. Outline = not saved, filled = saved.
private struct StarButton: View {
    let starred: Bool
    let theme: Theme
    let action: () -> Void
    @State private var hovering = false
    static let width: CGFloat = 28

    var body: some View {
        Button(action: action) {
            Image(systemName: starred ? "star.fill" : "star")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.iconColor.opacity(starred || hovering ? 1 : 0.7))
                .scaleEffect(hovering && !Motion.reduceMotion ? 1.12 : 1)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Self.width, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .notchHover { hovering = $0 }
        .animation(Motion.feedback, value: hovering)
        .help(starred ? "Remove this time from the starred ones" : "Star this time")
        .accessibilityLabel(starred ? "Remove star" : "Star this time")
    }
}

/// Shown instead of the Home tab while the alarm rings (SPEC §7.4): the length of each timer that ended, and a big Stop.
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
                Text(timers.ringing.count > 1 ? "Timers ended" : "Timer ended")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                ForEach(timers.ringing) { t in
                    Text(TimeFormat.label(t.duration))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                }
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
