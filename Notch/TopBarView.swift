import SwiftUI

/// The open notch's top row, as tall as the notch. Left and right of the real notch, the modules in
/// the user's order (Settings › Layout & Modules), without hidden or unavailable ones.
struct TopBarView: View {
    let geometry: NotchGeometry
    let theme: Theme
    let settings: AppSettings
    let showScreenBrightness: Bool
    let showKeyboardBrightness: Bool
    let tab: NotchTab
    let onSelectTab: (NotchTab) -> Void

    var body: some View {
        let g = geometry
        let leftWidth = max(0, g.notchRect.minX - g.openRect.minX)
        let rightWidth = max(0, g.openRect.maxX - g.notchRect.maxX)
        HStack(spacing: 0) {
            HStack(spacing: Spacing.xs) {
                ForEach(settings.leftModules.filter(settings.isVisible)) { module in
                    leftItem(module)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, Spacing.l)
            .frame(width: leftWidth, alignment: .leading)
            Spacer(minLength: 0)   // the real notch
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ToolButtonsView(theme: theme, tools: settings.visibleTools, onPick: { onSelectTab(.home) })
            }
            .padding(.trailing, Spacing.l)
            .frame(width: rightWidth, alignment: .trailing)
        }
        .frame(height: g.notchRect.height)
    }

    @ViewBuilder private func leftItem(_ module: TopModule) -> some View {
        let spring = settings.animations.brightness.animation
        switch module {
        case .homeFiles:
            TabSwitchView(selected: tab, theme: theme, onSelect: onSelectTab)
                .padding(.trailing, Spacing.xs)
        case .screenBrightness:
            if showScreenBrightness { BrightnessControl(kind: .screen, theme: theme, spring: spring) }
        case .keyboardBrightness:
            if showKeyboardBrightness { BrightnessControl(kind: .keyboard, theme: theme, spring: spring) }
        default:
            EmptyView()
        }
    }
}
