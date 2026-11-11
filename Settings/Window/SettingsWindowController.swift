import AppKit
import SwiftUI

/// The Settings window (SPEC §10). A normal window with a sidebar, like System Settings.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private init() {}

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Fonta's Dynamic Notch"
            w.titlebarAppearsTransparent = true
            w.toolbarStyle = .unified
            w.contentViewController = NSHostingController(rootView: SettingsView())
            w.setContentSize(NSSize(width: 760, height: 560))
            w.minSize = NSSize(width: 680, height: 460)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
