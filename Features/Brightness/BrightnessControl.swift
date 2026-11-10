import SwiftUI

/// Top-bar brightness button. Hovering expands it sideways into a slider capsule (the neighbours
/// slide aside); leaving collapses it, unless a drag is still going on.
struct BrightnessControl: View {
    let kind: BrightnessService.Kind
    let theme: Theme
    let spring: Animation
    private var service: BrightnessService { .shared }

    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        let expanded = hovering || dragging
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.iconColor.opacity(0.9))
                .frame(width: 16)
            if expanded {
                NotchSlider(value: service.level(kind), theme: theme,
                            onChange: { service.set(kind, $0) },
                            onEnd: { service.set(kind, $0) },
                            onEditingChanged: { dragging = $0 })
                    .frame(width: 84)
                    .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .leading)))
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(Capsule().fill(Color.white.opacity(expanded ? 0.12 : 0)))
        .contentShape(Capsule())
        .onHover { inside in
            hovering = inside
            if inside { service.refresh(kind) }   // follow changes made with the keyboard keys
        }
        .animation(spring, value: expanded)
        .help(kind == .screen ? "Screen brightness" : "Keyboard brightness")
    }

    private var symbol: String {
        let v = service.level(kind)
        switch kind {
        case .screen: return v < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .keyboard: return v < 0.01 ? "light.min" : "light.max"
        }
    }
}
