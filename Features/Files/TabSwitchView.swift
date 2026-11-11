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
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private func item(_ tab: NotchTab, _ symbol: String) -> some View {
        Button { onSelect(tab) } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.iconColor.opacity(selected == tab ? 1 : 0.5))
                .frame(width: 22, height: 20)
                .background(Capsule().fill(Color.white.opacity(selected == tab ? 0.18 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tab == .home ? "Home" : "Files")
    }
}
