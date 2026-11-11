import SwiftUI

/// The right-hand panel of the Home tab: shows the selected tool.
struct ToolPanelView: View {
    let theme: Theme
    let spring: Animation
    private var tools: ToolState { .shared }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
            Group {
                switch tools.selected {
                case .timer: TimerPanelView(theme: theme)
                case .stopwatch: StopwatchPanelView(theme: theme)
                case .counter: CounterPanelView(theme: theme)
                }
            }
            .padding(10)
            .transition(.opacity)
            .id(tools.selected)
        }
        .animation(spring, value: tools.selected)
    }
}

/// Top-bar buttons right of the notch: Timer, Stopwatch, Counter. The selected one is highlighted.
struct ToolButtonsView: View {
    let theme: Theme
    /// Called after a tool is picked (switches back to the Home tab).
    var onPick: () -> Void = {}
    private var tools: ToolState { .shared }
    private var timers: TimerStore { .shared }

    var body: some View {
        HStack(spacing: 4) {
            button(.timer, "timer", running: timers.anyRunning)
            button(.stopwatch, "stopwatch", running: StopwatchStore.shared.isRunning)
            button(.counter, "plusminus", running: false)
        }
    }

    private func button(_ tool: Tool, _ symbol: String, running: Bool) -> some View {
        let selected = tools.selected == tool
        return Button { tools.select(tool); onPick() } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.iconColor.opacity(selected ? 1 : 0.6))
                .frame(width: 28, height: 22)
                .background(Capsule().fill(Color.white.opacity(selected ? 0.16 : 0)))
                .overlay(alignment: .topTrailing) {
                    if running {
                        Circle().fill(theme.accent).frame(width: 4, height: 4).offset(x: -3, y: 3)
                    }
                }
        }
        .buttonStyle(NotchButtonStyle(radius: 11))
        .help(tool.rawValue.capitalized)
    }
}
