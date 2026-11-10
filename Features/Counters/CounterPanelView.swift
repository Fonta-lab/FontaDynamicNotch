import SwiftUI

/// Counter tool (SPEC §7.3): name with ‹ › to switch, big value, −1 / +1 / Reset.
struct CounterPanelView: View {
    let theme: Theme
    private var store: CounterStore { .shared }

    var body: some View {
        let multiple = store.counters.count > 1
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                arrow("chevron.left", enabled: multiple) { store.step(-1) }
                Text(store.selected?.name ?? "Counter")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                arrow("chevron.right", enabled: multiple) { store.step(1) }
            }
            Spacer(minLength: 0)
            Text("\(store.selected?.value ?? 0)")
                .font(.system(size: 30, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: store.selected?.value)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                button("−1") { store.add(-1) }
                button("+1") { store.add(1) }
                Button { store.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                        .frame(width: 30, height: 24)
                }
                .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, filled: true))
                .help("Reset to 0")
            }
        }
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, filled: true))
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.primaryText.opacity(enabled ? 0.8 : 0.25))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(NotchButtonStyle(radius: 9))
        .disabled(!enabled)
    }
}
