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
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = SettingsStore.shared
    private var screenManager: ScreenManager?
    private var statusItem: NSStatusItem?
    private var diagnosticsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        Task { [weak self] in
            guard let self else { return }
            await settings.load()
            let manager = ScreenManager(settingsStore: settings) { [weak self] in self?.makeMenu() ?? NSMenu() }
            manager.start()
            screenManager = manager
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        settings.flush()
    }

    // MARK: Menu bar icon

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Fonta's Dynamic Notch")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// The same menu, for right-clicking the open notch.
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        return menu
    }

    /// Rebuilt each time it opens so checkmarks are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settingsItem = NSMenuItem(title: "Settings… (coming in M9)", action: nil, keyEquivalent: "")
        settingsItem.isEnabled = false
        menu.addItem(settingsItem)

        let debug = NSMenu()
        let s = settings.settings
        debug.addItem(toggle("Show geometry overlay", s.showDebugOverlay, #selector(toggleOverlay)))
        debug.addItem(toggle("Notch on all screens", s.notchOnAllScreens, #selector(toggleAllScreens)))
        debug.addItem(toggle("Show fake notch when idle", s.showFakeNotchWhenIdle, #selector(toggleFakeIdle)))
        debug.addItem(.separator())
        debug.addItem(item("M0 Diagnostics…", #selector(showDiagnostics)))
        let debugItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
        debugItem.submenu = debug
        menu.addItem(debugItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    private func toggle(_ title: String, _ on: Bool, _ action: Selector) -> NSMenuItem {
        let i = item(title, action)
        i.state = on ? .on : .off
        return i
    }

    @objc private func toggleOverlay() { settings.settings.showDebugOverlay.toggle() }
    @objc private func toggleAllScreens() { settings.settings.notchOnAllScreens.toggle() }
    @objc private func toggleFakeIdle() { settings.settings.showFakeNotchWhenIdle.toggle() }

    @objc private func showDiagnostics() {
        if diagnosticsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 640),
                             styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = "M0 – Risk checks"
            w.contentView = NSHostingView(rootView: DiagnosticsView())
            w.isReleasedWhenClosed = false
            w.center()
            diagnosticsWindow = w
        }
        diagnosticsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
