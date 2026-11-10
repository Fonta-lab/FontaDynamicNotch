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
                case .stopwatch: comingSoon("Stopwatch", "M7")
                case .counter: comingSoon("Counter", "M7")
                }
            }
            .padding(10)
            .transition(.opacity)
            .id(tools.selected)
        }
        .animation(spring, value: tools.selected)
    }

    private func comingSoon(_ name: String, _ milestone: String) -> some View {
        Text("\(name) arrives in \(milestone)")
            .font(.system(size: 11))
            .foregroundStyle(theme.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Top-bar buttons right of the notch: Timer, Stopwatch, Counter. The selected one is highlighted.
struct ToolButtonsView: View {
    let theme: Theme
    private var tools: ToolState { .shared }
    private var timers: TimerStore { .shared }

    var body: some View {
        HStack(spacing: 4) {
            button(.timer, "timer", running: timers.anyRunning)
            button(.stopwatch, "stopwatch", running: false)
            button(.counter, "plusminus", running: false)
        }
    }

    private func button(_ tool: Tool, _ symbol: String, running: Bool) -> some View {
        let selected = tools.selected == tool
        return Button { tools.select(tool) } label: {
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
