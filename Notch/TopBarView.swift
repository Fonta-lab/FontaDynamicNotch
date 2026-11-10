import SwiftUI

/// The open notch's top row, as tall as the notch. Left of the notch: (Home/Files in M8), screen
/// brightness, keyboard brightness. Right of the notch: Timer, Stopwatch, Counter (M6–M7).
struct TopBarView: View {
    let geometry: NotchGeometry
    let theme: Theme
    let settings: AppSettings
    let showScreenBrightness: Bool
    let showKeyboardBrightness: Bool

    var body: some View {
        let g = geometry
        let leftWidth = max(0, g.notchRect.minX - g.openRect.minX)
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
            Spacer(minLength: 0)   // the real notch, then the right group (M6)
        }
        .frame(height: g.notchRect.height)
    }
}
