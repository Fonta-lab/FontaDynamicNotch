import SwiftUI

enum NotchTab: Sendable { case home, files }

/// Home / Files pair of icons at the start of the top bar (Boring-Notch style).
struct TabSwitchView: View {
    let selected: NotchTab
    let theme: Theme
    let onSelect: (NotchTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.home, "house.fill")
            item(.files, "folder.fill")
        }
        .padding(Spacing.xxs)
        .background(Capsule().fill(theme.primaryText.opacity(Highlight.panel)))
    }

    private func item(_ tab: NotchTab, _ symbol: String) -> some View {
        Button { onSelect(tab) } label: {
            Image(systemName: symbol)
                .font(.system(size: theme.topBarIconSize - 1, weight: .semibold))
                .foregroundStyle(theme.iconColor.opacity(selected == tab ? 1 : 0.5))
                .frame(width: 24, height: TopBarMetrics.itemHeight - Spacing.xxs * 2)
                .background(Capsule().fill(theme.primaryText.opacity(selected == tab ? Highlight.selected : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tab == .home ? "Home" : "Files")
        .accessibilityLabel(tab == .home ? "Home" : "Files")
        .accessibilityAddTraits(selected == tab ? .isSelected : [])
    }
}
