import SwiftUI

/// The idle timer's time, editable right in the notch (SPEC §7.1). Hovering shows small chevrons
/// above and below the hours, minutes and seconds: click them, or scroll over a number.
struct TimerDurationEditor: View {
    let duration: TimeInterval
    let theme: Theme
    @State private var hovering = false
    @State private var hideWork: DispatchWorkItem?

    /// Click area of each chevron. Only the glyph is drawn (no highlight box), and it sits in the
    /// empty space at the top / bottom of the digits' line, so it never covers the chips or buttons.
    private static let arrowHeight: CGFloat = 16
    private static let arrowWidth: CGFloat = 32
    /// How far each arrow's area tucks into the digits' line (its empty top / bottom).
    private nonisolated static let arrowTuckTop: CGFloat = 6
    private nonisolated static let arrowTuckBottom: CGFloat = 5

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
        .padding(.top, Self.arrowHeight - Self.arrowTuckTop)
        .padding(.bottom, Self.arrowHeight - Self.arrowTuckBottom)
        .contentShape(Rectangle())
        .onHover(perform: setHovering)
        .padding(.top, Self.arrowTuckTop - Self.arrowHeight)
        .padding(.bottom, Self.arrowTuckBottom - Self.arrowHeight)
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
                    .alignmentGuide(.top) { $0[.bottom] - Self.arrowTuckTop }
            }
            .overlay(alignment: .bottom) {
                arrow("chevron.down", unit, -1)
                    .alignmentGuide(.bottom) { $0[.top] + Self.arrowTuckBottom }
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
        StepArrow(symbol: symbol, color: theme.primaryText,
                  width: Self.arrowWidth, height: Self.arrowHeight) { change(unit, by: direction) }
            .opacity(hovering ? 1 : 0)
            .allowsHitTesting(hovering)
            .help(direction > 0 ? "More \(unit.name.lowercased())" : "Fewer \(unit.name.lowercased())")
            .accessibilityHidden(true)   // the segment itself is adjustable
    }

    private func change(_ unit: Unit, by steps: Int) {
        let new = min(TimerStore.maxDuration, max(1, duration + Double(steps) * unit.step))
        guard new != duration else { return }
        TimerStore.shared.setDuration(new)
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

/// A chevron with no box: dim at rest, full colour and a touch bigger under the mouse.
private struct StepArrow: View {
    let symbol: String
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(color.opacity(hovering ? 1 : 0.6))
                .scaleEffect(hovering && !Motion.reduceMotion ? 1.2 : 1)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.feedback, value: hovering)
    }
}
