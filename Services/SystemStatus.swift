import AppKit
import ServiceManagement
import UserNotifications

/// Small system checks for the Settings window.
enum SystemStatus {
    enum SpotifyPermission { case allowed, denied, notAsked, spotifyNotRunning, unknown }

    /// Asks macOS whether we may control Spotify, without showing a prompt. Off the main thread.
    static func spotifyPermission() async -> SpotifyPermission {
        await Task.detached(priority: .utility) { () -> SpotifyPermission in
            guard SpotifyScripting.isSpotifyRunning else { return .spotifyNotRunning }
            let target = NSAppleEventDescriptor(bundleIdentifier: SpotifyScripting.bundleID)
            let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false)
            switch status {
            case noErr: return .allowed
            case OSStatus(errAEEventNotPermitted): return .denied
            case OSStatus(errAEEventWouldRequireUserConsent): return .notAsked
            case OSStatus(procNotFound): return .spotifyNotRunning
            default: return .unknown
            }
        }.value
    }

    static func notificationsAllowed() async -> Bool? {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        switch s.authorizationStatus {
        case .authorized, .provisional: return true
        case .denied: return false
        default: return nil   // not asked yet
        }
    }

    static func requestNotifications() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    // MARK: Launch at login (SMAppService)

    static var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message, or nil on success.
    static func setLaunchAtLogin(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
