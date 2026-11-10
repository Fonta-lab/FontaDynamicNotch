import AppKit
import Observation

/// Now playing + transport for Spotify. Event-driven: it updates on Spotify's PlaybackStateChanged
/// notification and on launch/quit; it never polls while the notch is closed.
@MainActor @Observable
final class SpotifyService {
    static let shared = SpotifyService()

    private(set) var isRunning = false
    private(set) var permissionDenied = false
    private(set) var state: PlayerState = .stopped
    private(set) var track: SpotifyTrack?
    private(set) var shuffling = false
    private(set) var repeating = false
    private(set) var artwork: NSImage?
    private(set) var artworkColor: RGBColor?
    /// True once Spotify has been paused for longer than the "paused music stays visible" setting.
    private(set) var pausedExpired = false

    // Progress interpolation anchor
    private var position: Double = 0
    private var positionDate = Date()

    @ObservationIgnored private let scripting = SpotifyScripting()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pausedSince: Date?
    @ObservationIgnored private var pauseExpiryWork: DispatchWorkItem?
    @ObservationIgnored private var artworkTrackID: String?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?

    private init() {}

    var isPlaying: Bool { state == .playing }

    /// "Music active" (SPEC §4.1): running and playing, or paused for less than the setting.
    var isMusicActive: Bool {
        guard isRunning, track != nil else { return false }
        return state == .playing || (state == .paused && !pausedExpired)
    }

    /// Current playback position, interpolated locally while playing.
    func currentPosition(at date: Date = Date()) -> Double {
        var p = position
        if state == .playing { p += date.timeIntervalSince(positionDate) }
        return min(max(0, p), track?.duration ?? p)
    }

    // MARK: Lifecycle

    func start() {
        isRunning = SpotifyScripting.isSpotifyRunning
        let ws = NSWorkspace.shared.notificationCenter
        observers.append(ws.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let id = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { if id == SpotifyScripting.bundleID { self?.spotifyLaunched() } }
        })
        observers.append(ws.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let id = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { if id == SpotifyScripting.bundleID { self?.spotifyQuit() } }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] n in
            let info = n.userInfo ?? [:]
            let stateText = (info["Player State"] as? String)?.lowercased() ?? ""
            let pos = info["Playback Position"] as? Double
            let trackID = info["Track ID"] as? String
            MainActor.assumeIsolated { self?.playbackChanged(stateText: stateText, position: pos, trackID: trackID) }
        })
        if isRunning { refresh() }
    }

    private func spotifyLaunched() {
        isRunning = true
        refresh()
    }

    private func spotifyQuit() {
        isRunning = false
        apply(SpotifySnapshot(state: .stopped, position: 0, shuffling: shuffling, repeating: repeating, track: nil))
    }

    private func playbackChanged(stateText: String, position pos: Double?, trackID: String?) {
        isRunning = SpotifyScripting.isSpotifyRunning
        // Spotify posts "Stopped" while quitting: never script it then, or it could relaunch.
        if stateText == "stopped" || !isRunning {
            state = .stopped
            updatePauseExpiry()
            return
        }
        // Apply what the notification already tells us, then fetch the rest (artwork URL, shuffle, repeat).
        state = stateText == "playing" ? .playing : .paused
        if let pos { position = pos; positionDate = Date() }
        updatePauseExpiry()
        refresh()
    }

    // MARK: Refresh

    func refresh() {
        guard SpotifyScripting.isSpotifyRunning else { isRunning = false; return }
        Task {
            let result = await scripting.run(SpotifyScripting.readState, parse: SpotifyScripting.parseState)
            handle(result)
        }
    }

    private func handle(_ result: Result<SpotifySnapshot, SpotifyScriptError>) {
        switch result {
        case .success(let snap):
            permissionDenied = false
            apply(snap)
        case .failure(.permissionDenied):
            permissionDenied = true
        case .failure(.notRunning):
            isRunning = false
        case .failure(let e):
            NSLog("Spotify script failed: \(e)")
        }
    }

    private func apply(_ s: SpotifySnapshot) {
        state = s.state
        position = s.position
        positionDate = Date()
        shuffling = s.shuffling
        repeating = s.repeating
        if track != s.track { track = s.track }
        updatePauseExpiry()
        loadArtworkIfNeeded()
    }

    private func updatePauseExpiry() {
        pauseExpiryWork?.cancel()
        pauseExpiryWork = nil
        guard state == .paused else {
            pausedSince = nil
            pausedExpired = false
            return
        }
        let since = pausedSince ?? Date()
        pausedSince = since
        let limit = SettingsStore.shared.settings.pausedMusicVisibleMinutes * 60
        let remaining = limit - Date().timeIntervalSince(since)
        if remaining <= 0 {
            pausedExpired = true
            return
        }
        pausedExpired = false
        // One-shot timer, only while paused.
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.pausedExpired = true } }
        pauseExpiryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
    }

    // MARK: Artwork

    private func loadArtworkIfNeeded() {
        guard let track else {
            artworkTrackID = nil
            artworkTask?.cancel()
            artwork = nil
            artworkColor = nil
            return
        }
        guard track.id != artworkTrackID else { return }
        artworkTrackID = track.id
        artworkTask?.cancel()
        guard let url = track.artworkURL else {
            artwork = nil
            artworkColor = nil
            return
        }
        let id = track.id
        artworkTask = Task {
            let result = await ArtworkLoader.shared.load(id: id, url: url)
            guard !Task.isCancelled, artworkTrackID == id else { return }
            artwork = result.map { NSImage(cgImage: $0.image, size: .zero) }
            artworkColor = result?.color
        }
    }

    // MARK: Commands

    func playPause() {
        // Optimistic update so the button reacts instantly.
        position = currentPosition()
        positionDate = Date()
        state = state == .playing ? .paused : .playing
        updatePauseExpiry()
        send("tell application \"Spotify\" to playpause")
    }

    func nextTrack() { send("tell application \"Spotify\" to next track") }
    func previousTrack() { send("tell application \"Spotify\" to previous track") }

    func seek(to seconds: Double) {
        position = seconds
        positionDate = Date()
        send(String(format: "tell application \"Spotify\" to set player position to %.3f", seconds), cache: false)
    }

    func toggleShuffle() {
        shuffling.toggle()
        send("tell application \"Spotify\" to set shuffling to \(shuffling)", cache: false, refreshAfter: true)
    }

    func toggleRepeat() {
        repeating.toggle()
        send("tell application \"Spotify\" to set repeating to \(repeating)", cache: false, refreshAfter: true)
    }

    private func send(_ source: String, cache: Bool = true, refreshAfter: Bool = false) {
        guard SpotifyScripting.isSpotifyRunning else { isRunning = false; return }
        Task {
            let r = await scripting.command(source, cache: cache)
            switch r {
            case .failure(.permissionDenied): permissionDenied = true
            case .failure(let e): NSLog("Spotify command failed: \(e)")
            case .success: break
            }
            // Shuffle/repeat don't post a playback notification, so read back the real value.
            if refreshAfter {
                try? await Task.sleep(for: .milliseconds(300))
                refresh()
            }
        }
    }

    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SpotifyScripting.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
