import SwiftUI

/// Shared look of the three tool panels, so the timer, stopwatch and counter match.
enum ToolPanelStyle {
    /// The big number (time or count): Large Title, semibold, digits that don't jitter.
    static let valueFont = Font.largeTitle.weight(.semibold).monospacedDigit()
}

/// The right-hand panel of the Home tab: shows the selected tool.
struct ToolPanelView: View {
    let theme: Theme
    let spring: Animation
    let visibleTools: [Tool]
    private var tools: ToolState { .shared }

    var body: some View {
        // If the selected tool was hidden in Settings, show the first visible one.
        let tool = visibleTools.contains(tools.selected) ? tools.selected : (visibleTools.first ?? .timer)
        ZStack {
            RoundedRectangle(cornerRadius: theme.panelRadius, style: .continuous)
                .fill(theme.primaryText.opacity(Highlight.panel))
            Group {
                switch tool {
                case .timer: TimerPanelView(theme: theme)
                case .stopwatch: StopwatchPanelView(theme: theme)
                case .counter: CounterPanelView(theme: theme)
                }
            }
            .padding(Spacing.s)
            .transition(.opacity)
            .id(tool)
        }
        .animation(spring, value: tool)
    }
}

/// Top-bar buttons right of the notch: Timer, Stopwatch, Counter. The selected one is highlighted.
struct ToolButtonsView: View {
    let theme: Theme
    /// Visible tools in the user's order.
    let tools: [Tool]
    /// Called after a tool is picked (switches back to the Home tab).
    var onPick: () -> Void = {}
    private var state: ToolState { .shared }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(tools, id: \.self) { tool in
                switch tool {
                case .timer: button(.timer, "timer", running: TimerStore.shared.anyRunning)
                case .stopwatch: button(.stopwatch, "stopwatch", running: StopwatchStore.shared.isRunning)
                case .counter: button(.counter, "plusminus", running: false)
                }
            }
        }
    }

    private func button(_ tool: Tool, _ symbol: String, running: Bool) -> some View {
        let selected = state.selected == tool
        return Button { state.select(tool); onPick() } label: {
            Image(systemName: symbol)
                .font(.system(size: theme.topBarIconSize, weight: .semibold))
                .foregroundStyle(theme.iconColor.opacity(selected ? 1 : 0.6))
                .frame(width: 28, height: TopBarMetrics.itemHeight)
                .background(Capsule().fill(theme.primaryText.opacity(selected ? Highlight.selected : 0)))
                .overlay(alignment: .topTrailing) {
                    if running {
                        Circle().fill(theme.accent).frame(width: 4, height: 4).offset(x: -3, y: 3)
                    }
                }
        }
        .buttonStyle(NotchButtonStyle(radius: TopBarMetrics.itemHeight / 2, tint: theme.primaryText))
        .help(tool.rawValue.capitalized)
    }
}
