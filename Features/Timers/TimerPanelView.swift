import SwiftUI

/// Timer tool (SPEC §7.1): 5 chips, the selected timer's name and time, Start/Pause and Reset.
struct TimerPanelView: View {
    let theme: Theme
    private var store: TimerStore { .shared }

    var body: some View {
        let selected = store.selected
        VStack(spacing: 4) {
            chips(selectedID: selected?.id)
            Spacer(minLength: 0)
            Text(selected?.name ?? "")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            if let selected {
                // Refreshes only while this panel is visible and the timer runs.
                TimelineView(.animation(minimumInterval: 0.25, paused: !selected.isRunning)) { ctx in
                    Text(TimeFormat.countdown(store.remaining(selected, at: ctx.date)))
                        .font(ToolPanelStyle.valueFont)
                        .foregroundStyle(timeColor(selected))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            Spacer(minLength: 0)
            if let selected { controls(selected) }
        }
    }

    private func chips(selectedID: UUID?) -> some View {
        HStack(spacing: 3) {
            ForEach(store.presets) { p in
                let isSelected = p.id == selectedID
                Button { store.select(p.id) } label: {
                    Text(p.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(theme.primaryText.opacity(isSelected ? 1 : 0.65))
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity, minHeight: 18)
                        .background(Capsule().fill(Color.white.opacity(isSelected ? 0.2 : 0.06)))
                        .overlay(alignment: .topTrailing) {
                            if p.isRunning || p.isRinging {
                                Circle().fill(p.isRinging ? Color.red : theme.accent)
                                    .frame(width: 4, height: 4).offset(x: -2, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(p.name)
            }
        }
    }

    private func controls(_ p: TimerPreset) -> some View {
        let (help, symbol): (String, String) = switch p.run {
        case .running: ("Pause", "pause.fill")
        case .paused: ("Resume", "play.fill")
        default: ("Start", "play.fill")
        }
        return HStack(spacing: 6) {
            PanelButton(theme: theme, symbol: symbol, enabled: !p.isRinging, help: help) { store.toggle(p.id) }
            PanelButton(theme: theme, symbol: "arrow.counterclockwise", enabled: p.run != .idle, help: "Reset") { store.reset(p.id) }
        }
    }

    private func timeColor(_ p: TimerPreset) -> Color {
        switch p.run {
        case .paused: theme.primaryText.opacity(0.55)
        case .ringing: .red
        default: theme.primaryText
        }
    }
}

/// Shown instead of the Home tab while an alarm rings (SPEC §7.4): the timer name(s) and a big Stop.
struct AlarmView: View {
    let theme: Theme
    @State private var pulse = false
    private var timers: TimerStore { .shared }

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .scaleEffect(pulse ? 1.08 : 0.94)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            VStack(alignment: .leading, spacing: 3) {
                Text(timers.ringing.count > 1 ? "Timers ended" : "Timer ended")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(timers.ringing) { t in
                            Text(t.name)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxHeight: 70)
                .fixedSize(horizontal: false, vertical: true)
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
        .padding(.horizontal, 8)
    }
}
