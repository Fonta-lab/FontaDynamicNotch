import SwiftUI
import AppKit

@main
struct FontaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "stethoscope", accessibilityDescription: "M0")
        let menu = NSMenu()
        menu.addItem(withTitle: "M0 Tests…", action: #selector(showTests), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = $0.action == #selector(showTests) ? self : nil }
        item.menu = menu
        statusItem = item
        showTests()
    }

    @objc func showTests() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 640),
                             styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = "M0 – Risk checks"
            w.contentView = NSHostingView(rootView: DiagnosticsView())
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
