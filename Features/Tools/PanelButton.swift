import SwiftUI

/// The square-ish buttons at the bottom of the tool panels. Equal width, content centred.
struct PanelButton: View {
    let theme: Theme
    var symbol: String? = nil
    var title: String? = nil
    var enabled = true
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.subheadline.weight(.semibold)) }
                if let title { Text(title).font(.body.weight(.bold).monospacedDigit()) }
            }
            .foregroundStyle(theme.primaryText.opacity(enabled ? 1 : 0.35))
            .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(radius: theme.buttonRadius, filled: true, padded: false))
        .disabled(!enabled)
        .help(help)
    }
}
