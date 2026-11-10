import Foundation
import AppKit

@MainActor
final class SpotifyProbe {
    var onLog: ((String) -> Void)?
    private var observer: NSObjectProtocol?
    private let queue = DispatchQueue(label: "spotify.probe")

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
    }

    func startListening() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] n in
            let info = n.userInfo ?? [:]
            let summary = info.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
            MainActor.assumeIsolated { self?.onLog?("Notification received: \(summary)") }
        }
    }

    func read() {
        guard isRunning else { onLog?("Spotify is not running (and I did NOT launch it). Open Spotify, play a song, then try again."); return }
        let src = """
        tell application "Spotify"
          set s to player state as string
          set p to player position
          set sh to shuffling
          set rp to repeating
          set rpClass to (class of rp) as string
          set t to ""
          try
            set t to (name of current track) & " — " & (artist of current track) & " | id " & (id of current track) & " | dur " & (duration of current track) & " | art " & (artwork url of current track)
          end try
          return s & " | pos " & p & " | shuffle " & sh & " | repeat " & rp & " (" & rpClass & ") | " & t
        end tell
        """
        run(src, label: "Read state")
    }

    func playPause() {
        guard isRunning else { onLog?("Spotify is not running."); return }
        run("tell application \"Spotify\" to playpause", label: "Play/Pause")
    }

    func toggleRepeat() {
        guard isRunning else { onLog?("Spotify is not running."); return }
        run("""
        tell application "Spotify"
          set oldVal to repeating
          set repeating to (not oldVal)
          set newVal to repeating
          set repeating to oldVal
          return "repeat was " & oldVal & ", changed to " & newVal & ", restored"
        end tell
        """, label: "Repeat toggle test")
    }

    private func run(_ source: String, label: String) {
        queue.async { [weak self] in
            var err: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
            let text: String
            if let err { text = "FAIL: \(err[NSAppleScript.errorMessage] ?? err) (code \(err[NSAppleScript.errorNumber] ?? "?"))" }
            else { text = "OK: \(result?.stringValue ?? "(no result)")" }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.onLog?("\(label) → \(text)") } }
        }
    }
}
