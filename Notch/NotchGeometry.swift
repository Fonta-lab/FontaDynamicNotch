import AppKit

/// All the rectangles for one screen's notch.
/// Local rects use SwiftUI coordinates inside the panel: origin at the panel's top-left, y grows downward.
struct NotchGeometry: Equatable {
    /// Room around the open shape for the shadow and the top fillets (M2).
    static let margin: CGFloat = 24
    /// Fallback width for a fake notch when no built-in notch is known. [Guess]
    static let defaultFakeNotchWidth: CGFloat = 185

    var hasRealNotch: Bool
    var notchSize: CGSize
    var panelFrame: CGRect      // global AppKit coordinates
    var notchRect: CGRect       // local
    var openRect: CGRect        // local
    var wingWidth: CGFloat
    var closedHeight: CGFloat   // notch height + the user's fine-tune

    /// The closed black shape: the notch, plus a wing on each side when something is showing.
    func closedRect(wings: Bool) -> CGRect {
        let base = CGRect(x: notchRect.minX, y: 0, width: notchRect.width, height: closedHeight)
        return wings ? base.insetBy(dx: -wingWidth, dy: 0) : base
    }

    /// Where hovering opens the notch: the closed shape, a little wider and taller. [Guess]
    func hotZone(wings: Bool) -> CGRect {
        let c = closedRect(wings: wings)
        return CGRect(x: c.minX - 8, y: 0, width: c.width + 16, height: c.height + 4)
    }

    /// Left and right wing areas (local).
    var leftWing: CGRect { CGRect(x: notchRect.minX - wingWidth, y: 0, width: wingWidth, height: closedHeight) }
    var rightWing: CGRect { CGRect(x: notchRect.maxX, y: 0, width: wingWidth, height: closedHeight) }

    static func compute(screen: NSScreen, settings: AppSettings, knownNotchWidth: CGFloat?) -> NotchGeometry {
        let frame = screen.frame
        let safeTop = screen.safeAreaInsets.top
        let real: Bool
        var notchW: CGFloat
        let notchH: CGFloat
        var centerX = frame.midX

        if safeTop > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            real = true
            notchW = frame.width - left.width - right.width
            notchH = safeTop
            centerX = frame.minX + left.width + notchW / 2
        } else {
            real = false
            notchW = knownNotchWidth ?? defaultFakeNotchWidth
            let menuBar = frame.maxY - screen.visibleFrame.maxY
            notchH = menuBar > 0 ? menuBar : NSStatusBar.system.thickness
        }
        notchW = max(notchW, 60)

        let openW = max(CGFloat(settings.openWidth), notchW + 120)
        let openH = max(CGFloat(settings.openHeight), notchH + 60)
        let panelW = openW + margin * 2
        let panelH = openH + margin
        let panelFrame = CGRect(x: (centerX - panelW / 2).rounded(), y: frame.maxY - panelH, width: panelW, height: panelH)

        let notchRect = CGRect(x: (panelW - notchW) / 2, y: 0, width: notchW, height: notchH)
        let openRect = CGRect(x: (panelW - openW) / 2, y: 0, width: openW, height: openH)
        let wing = min(CGFloat(settings.closedWingWidth), (openW - notchW) / 2)

        return NotchGeometry(hasRealNotch: real, notchSize: CGSize(width: notchW, height: notchH),
                             panelFrame: panelFrame, notchRect: notchRect, openRect: openRect, wingWidth: wing,
                             closedHeight: max(notchH, notchH + CGFloat(settings.closedHeightExtra)))
    }

    /// Converts a local rect to global AppKit coordinates.
    func toGlobal(_ r: CGRect) -> CGRect {
        CGRect(x: panelFrame.minX + r.minX, y: panelFrame.maxY - r.maxY, width: r.width, height: r.height)
    }
}
