import SwiftUI

/// The idle timer's time, set right in the notch (SPEC §7.1). Hovering a number (hours, minutes
/// or seconds) gives it a soft highlight; scroll over it, or drag it up or down, to change it.
/// Up = more. Clicking the hours rounds to the hour (mm:ss → 00:00); clicking the minutes rounds
/// to the minute (ss → 00). No extra buttons.
struct TimerDurationEditor: View {
    let duration: TimeInterval
    let theme: Theme
    var font: Font = ToolPanelStyle.valueFont

    enum Unit: CaseIterable {
        case hours, minutes, seconds
        var step: TimeInterval {
            switch self {
            case .hours: 3600
            case .minutes: 60
            case .seconds: 1
            }
        }
        var name: String {
            switch self {
            case .hours: "Hours"
            case .minutes: "Minutes"
            case .seconds: "Seconds"
            }
        }
    }

    var body: some View {
        let total = Int(duration.rounded())
        let h = total / 3600, m = total / 60 % 60, s = total % 60
        // Same look as the running time (m:ss, or h:mm:ss from one hour), so nothing jumps on Start.
        // The minutes and seconds keep their place in the view tree when the hours appear, so a
        // drag that crosses one hour isn't interrupted.
        HStack(spacing: 0) {
            if h > 0 {
                segment(.hours, "\(h)", value: h)
                colon
            }
            segment(.minutes, h > 0 ? String(format: "%02d", m) : "\(m)", value: m)
            colon
            segment(.seconds, String(format: "%02d", s), value: s)
        }
        .font(font)
        .foregroundStyle(theme.primaryText)
        .lineLimit(1)
        .fixedSize()
    }

    private var colon: some View {
        Text(":").accessibilityHidden(true)
    }

    private func segment(_ unit: Unit, _ text: String, value: Int) -> some View {
        TimeSegment(text: text, unit: unit, value: value, theme: theme,
                    onStep: { change(unit, by: $0) },
                    onTap: unit == .seconds ? nil : { roundDown(to: unit) })
    }

    /// Clears everything smaller than `unit`: hours → minutes and seconds 00, minutes → seconds 00.
    /// Nothing happens if that would leave 0:00.
    private func roundDown(to unit: Unit) {
        let new = (duration / unit.step).rounded(.down) * unit.step
        guard new >= 1, new != duration else { return }
        TimerStore.shared.setDuration(new)
    }

    private func change(_ unit: Unit, by steps: Int) {
        let new = min(TimerStore.maxDuration, max(1, duration + Double(steps) * unit.step))
        guard new != duration else { return }
        TimerStore.shared.setDuration(new)
    }
}

/// One number of the time: highlight on hover, scroll or vertical drag to change it.
private struct TimeSegment: View {
    let text: String
    let unit: TimerDurationEditor.Unit
    let value: Int
    let theme: Theme
    let onStep: (Int) -> Void
    /// Click / tap (hours and minutes only): round down to this unit.
    let onTap: (() -> Void)?

    @State private var hovering = false
    @State private var dragging = false
    /// Steps already applied during the current drag.
    @State private var dragSteps = 0

    /// Points of vertical drag per step.
    private static let dragPerStep: CGFloat = 6

    var body: some View {
        let highlighted = hovering || dragging
        Text(text)
            .background(
                // A soft pill around the digits (not the line's empty top and bottom).
                RoundedRectangle(cornerRadius: theme.buttonRadius(height: 26), style: .continuous)
                    .fill(theme.primaryText.opacity(highlighted ? Highlight.hover : 0))
                    .padding(.horizontal, -3)
                    .padding(.vertical, 3)
            )
            .overlay { ScrollWheelCatcher(onStep: onStep) }
            .contentShape(Rectangle())
            .gesture(
                // A drag changes the number; a click without moving rounds (see onTap).
                DragGesture(minimumDistance: 2)
                    .onChanged { g in
                        dragging = true
                        let steps = Int((-g.translation.height / Self.dragPerStep).rounded(.towardZero))
                        if steps != dragSteps {
                            onStep(steps - dragSteps)
                            dragSteps = steps
                        }
                    }
                    .onEnded { _ in
                        dragging = false
                        dragSteps = 0
                    }
                    .exclusively(before: TapGesture().onEnded { onTap?() })
            )
            .notchHover { hovering = $0 }
            .animation(Motion.feedback, value: highlighted)
            .help(helpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(unit.name)
            .accessibilityValue("\(value)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onStep(1)
                case .decrement: onStep(-1)
                @unknown default: break
                }
            }
            .accessibilityAction(named: unit == .hours ? "Round to the hour" : "Round to the minute") { onTap?() }
    }

    private var helpText: String {
        let change = "Scroll, or drag up or down, to change the \(unit.name.lowercased())"
        switch unit {
        case .hours: return change + ". Click to set minutes and seconds to 00."
        case .minutes: return change + ". Click to set the seconds to 00."
        case .seconds: return change + "."
        }
    }
}
