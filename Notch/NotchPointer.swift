import SwiftUI

/// Where the mouse is inside this screen's open notch, in panel coordinates (origin top-left,
/// y down — the same space as SwiftUI's `.global` frames in the notch), or nil when it's outside
/// or the notch is closed. Fed by the app's own mouse tracking (MouseTracker → NotchController).
///
/// Why: the notch panel never becomes key and the app is never active, so SwiftUI's `onHover`
/// (AppKit tracking areas) reacts late there and sometimes misses the mouse leaving a button.
@MainActor @Observable
final class NotchPointer {
    var location: CGPoint?
}

extension EnvironmentValues {
    @Entry var notchPointer: NotchPointer? = nil
}

/// `onHover` driven by `NotchPointer`. Outside the notch (no pointer in the environment) it falls
/// back to SwiftUI's own `onHover`.
private struct NotchHoverModifier: ViewModifier {
    let action: (Bool) -> Void
    @Environment(\.notchPointer) private var pointer
    @State private var frame: CGRect = .zero
    @State private var inside = false

    func body(content: Content) -> some View {
        if let pointer {
            let now = pointer.location.map { frame.contains($0) } ?? false
            content
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
                .onChange(of: now, initial: true) { _, isInside in
                    guard isInside != inside else { return }
                    inside = isInside
                    action(isInside)
                }
        } else {
            content.onHover(perform: action)
        }
    }
}

extension View {
    /// Use instead of `onHover` inside the notch: instant and never left stuck on.
    func notchHover(perform action: @escaping (Bool) -> Void) -> some View {
        modifier(NotchHoverModifier(action: action))
    }
}
