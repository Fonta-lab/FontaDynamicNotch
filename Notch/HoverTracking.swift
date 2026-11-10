import SwiftUI
import AppKit

extension View {
    /// Hover that works in the notch panel. SwiftUI's `onHover` can stay silent there because the
    /// panel never becomes the key window and the app is usually not active; this uses an AppKit
    /// tracking area that is always active.
    func notchHover(_ action: @escaping (Bool) -> Void) -> some View {
        overlay(HoverTrackingView(onChange: action))
    }
}

private struct HoverTrackingView: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let v = TrackingNSView()
        v.onChange = onChange
        return v
    }

    func updateNSView(_ v: TrackingNSView, context: Context) {
        v.onChange = onChange
    }

    final class TrackingNSView: NSView {
        var onChange: ((Bool) -> Void)?
        private var inside = false

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero,
                                           options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                           owner: self, userInfo: nil))
        }

        override func mouseEntered(with event: NSEvent) { set(true) }
        override func mouseExited(with event: NSEvent) { set(false) }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { set(false) }
        }

        private func set(_ value: Bool) {
            guard value != inside else { return }
            inside = value
            onChange?(value)
        }

        /// Never take clicks: they go to the SwiftUI content underneath.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
