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

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        Task { [weak self] in
            guard let self else { return }
            await settings.load()
            await ThemeStore.shared.load()
            statusItem?.isVisible = settings.settings.showMenuBarIcon
            observeMenuBarIconSetting()
            SpotifyService.shared.start()
            AudioService.shared.start()
            BrightnessService.shared.start()
            let manager = ScreenManager(settingsStore: settings) { [weak self] in self?.makeMenu() ?? NSMenu() }
            AlarmService.shared.onRingingChanged = { [weak manager] ringing in manager?.alarmChanged(ringing: ringing) }
            manager.start()
            screenManager = manager
            await StateStore.shared.load()   // timers (may ring/notify, so screens must exist first)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        settings.flush()
        StateStore.shared.flush()
    }

    /// Opening the app again (e.g. from Finder) while it runs shows Settings, so it's always reachable.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return false
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

    /// Hides or shows the menu-bar icon live when the setting changes.
    private func observeMenuBarIconSetting() {
        withObservationTracking {
            _ = settings.settings.showMenuBarIcon
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.statusItem?.isVisible = self.settings.settings.showMenuBarIcon
                self.observeMenuBarIconSetting()
            }
        }
    }

    /// The same menu, for right-clicking the open notch (so Settings is reachable with the icon hidden).
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Fonta's Dynamic Notch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }
}
