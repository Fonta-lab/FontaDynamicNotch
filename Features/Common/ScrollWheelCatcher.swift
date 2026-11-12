import SwiftUI
import AppKit

/// Turns scrolling (trackpad or mouse wheel) over a view into +1 / −1 steps.
/// A physical "up" gesture (fingers or wheel moving up) is +1, whatever the natural-scrolling setting.
/// Only scroll events stop here: clicks and hovers pass through to the SwiftUI view underneath.
struct ScrollWheelCatcher: NSViewRepresentable {
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onStep = onStep
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onStep = onStep
    }

    final class CatcherView: NSView {
        var onStep: ((Int) -> Void)?
        private var accumulated: CGFloat = 0
        /// Trackpad points per step.
        private let threshold: CGFloat = 8

        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .scrollWheel ? super.hitTest(point) : nil
        }

        override func scrollWheel(with event: NSEvent) {
            // Momentum (the glide after lifting the fingers) is ignored, so the value stops where you stop.
            guard event.momentumPhase.isEmpty else { return }
            if event.phase == .began { accumulated = 0 }
            var dy = event.scrollingDeltaY
            if event.isDirectionInvertedFromDevice { dy = -dy }
            if !event.hasPreciseScrollingDeltas { dy *= threshold }   // one mouse-wheel click = one step
            accumulated += dy
            while abs(accumulated) >= threshold {
                let step = accumulated > 0 ? 1 : -1
                onStep?(step)
                accumulated -= CGFloat(step) * threshold
            }
        }
    }
}
