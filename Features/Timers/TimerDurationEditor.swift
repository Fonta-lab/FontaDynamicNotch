import SwiftUI

/// The idle timer's time, editable right in the notch (SPEC §7.1). Hovering shows ▲▼ above and
/// below the hours, minutes and seconds: click them, or scroll over a number. Every change is
/// saved into the chip (TimerStore.setDuration).
struct TimerDurationEditor: View {
    let preset: TimerPreset
    let theme: Theme
    /// True while the arrows show (the panel hides the timer's name, which the arrows cover).
    @Binding var hovering: Bool
    @State private var hideWork: DispatchWorkItem?

    static let maxDuration: TimeInterval = 24 * 3600 - 1
    /// The ▲▼ sit in the room above and below the digits; the hover area reaches that far too.
    private static let arrowHeight: CGFloat = 20
    /// How far the arrows tuck into the empty space at the top and bottom of the digits' line.
    private nonisolated static let arrowTuck: CGFloat = 5

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
        let total = Int(preset.duration.rounded())
        let h = total / 3600, m = total / 60 % 60, s = total % 60
        // Same look as the running time (m:ss, or h:mm:ss from one hour), so nothing jumps on Start.
        HStack(spacing: 0) {
            if h > 0 {
                segment(.hours, "\(h)", value: h)
                colon
                segment(.minutes, String(format: "%02d", m), value: m)
            } else {
                segment(.minutes, "\(m)", value: m)
            }
            colon
            segment(.seconds, String(format: "%02d", s), value: s)
        }
        .font(ToolPanelStyle.valueFont)
        .foregroundStyle(theme.primaryText)
        .lineLimit(1)
        .fixedSize()
        // Hover area includes the arrows above and below (the layout size doesn't change).
        .padding(.vertical, Self.arrowHeight - Self.arrowTuck)
        .contentShape(Rectangle())
        .onHover(perform: setHovering)
        .padding(.vertical, Self.arrowTuck - Self.arrowHeight)
        .animation(Motion.feedback, value: hovering)
    }

    private var colon: some View {
        Text(":").accessibilityHidden(true)
    }

    private func segment(_ unit: Unit, _ text: String, value: Int) -> some View {
        Text(text)
            .overlay { ScrollWheelCatcher { change(unit, by: $0) } }
            .overlay(alignment: .top) {
                arrow("chevron.up", unit, +1)
                    .alignmentGuide(.top) { $0[.bottom] - Self.arrowTuck }
            }
            .overlay(alignment: .bottom) {
                arrow("chevron.down", unit, -1)
                    .alignmentGuide(.bottom) { $0[.top] + Self.arrowTuck }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(unit.name)
            .accessibilityValue("\(value)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: change(unit, by: 1)
                case .decrement: change(unit, by: -1)
                @unknown default: break
                }
            }
    }

    private func arrow(_ symbol: String, _ unit: Unit, _ direction: Int) -> some View {
        Button { change(unit, by: direction) } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.primaryText.opacity(0.8))
                .frame(width: 28, height: Self.arrowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius(height: Self.arrowHeight), tint: theme.primaryText))
        .opacity(hovering ? 1 : 0)
        .allowsHitTesting(hovering)
        .help(direction > 0 ? "More \(unit.name.lowercased())" : "Fewer \(unit.name.lowercased())")
        .accessibilityHidden(true)   // the segment itself is adjustable
    }

    private func change(_ unit: Unit, by steps: Int) {
        let new = min(Self.maxDuration, max(1, preset.duration + Double(steps) * unit.step))
        guard new != preset.duration else { return }
        TimerStore.shared.setDuration(preset.id, new)
    }

    /// Shows the arrows at once; hides them after a short grace period, so moving from the digits
    /// onto an arrow never makes it vanish under the cursor.
    private func setHovering(_ inside: Bool) {
        hideWork?.cancel()
        hideWork = nil
        if inside {
            hovering = true
        } else {
            let work = DispatchWorkItem { hovering = false }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }
}
