import SwiftUI

/// The open notch's top row, as tall as the notch. Left of the notch: (Home/Files in M8), screen
/// brightness, keyboard brightness. Right of the notch: Timer, Stopwatch, Counter.
struct TopBarView: View {
    let geometry: NotchGeometry
    let theme: Theme
    let settings: AppSettings
    let showScreenBrightness: Bool
    let showKeyboardBrightness: Bool

    var body: some View {
        let g = geometry
        let leftWidth = max(0, g.notchRect.minX - g.openRect.minX)
        let rightWidth = max(0, g.openRect.maxX - g.notchRect.maxX)
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                if showScreenBrightness {
                    BrightnessControl(kind: .screen, theme: theme, spring: settings.animations.brightness.animation)
                }
                if showKeyboardBrightness {
                    BrightnessControl(kind: .keyboard, theme: theme, spring: settings.animations.brightness.animation)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 16)
            .frame(width: leftWidth, alignment: .leading)
            Spacer(minLength: 0)   // the real notch
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ToolButtonsView(theme: theme)
            }
            .padding(.trailing, 16)
            .frame(width: rightWidth, alignment: .trailing)
        }
        .frame(height: g.notchRect.height)
    }
}
