import SwiftUI

/// Counter tool (SPEC §7.3): name with ‹ › to switch, big value, −1 / +1 / Reset.
struct CounterPanelView: View {
    let theme: Theme
    private var store: CounterStore { .shared }

    var body: some View {
        let multiple = store.counters.count > 1
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                arrow("chevron.left", enabled: multiple) { store.step(-1) }
                Text(store.selected?.name ?? "Counter")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                arrow("chevron.right", enabled: multiple) { store.step(1) }
            }
            Spacer(minLength: 0)
            Text("\(store.selected?.value ?? 0)")
                .font(ToolPanelStyle.valueFont)
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: store.selected?.value)
            Spacer(minLength: 0)
            HStack(spacing: Spacing.s) {
                PanelButton(theme: theme, title: "−1") { store.add(-1) }
                PanelButton(theme: theme, title: "+1") { store.add(1) }
                PanelButton(theme: theme, symbol: "arrow.counterclockwise", help: "Reset to 0") { store.reset() }
            }
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.primaryText.opacity(enabled ? 0.8 : 0.25))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius(height: 18), tint: theme.primaryText))
        .disabled(!enabled)
    }
}
