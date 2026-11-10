import AppKit

struct SpotifyTrack: Equatable, Sendable {
    var id: String
    var name: String
    var artist: String
    var album: String
    var duration: Double        // seconds
    var artworkURL: URL?
}

enum PlayerState: String, Sendable {
    case stopped, playing, paused
}

struct SpotifySnapshot: Sendable {
    var state: PlayerState
    var position: Double
    var shuffling: Bool
    var repeating: Bool
    var track: SpotifyTrack?
}

enum SpotifyScriptError: Error, Sendable {
    case notRunning
    case permissionDenied
    case failed(String)
}

/// Runs Spotify AppleScript on one serial background queue (NSAppleScript is not thread-safe).
/// Every run checks first that Spotify is running, because `tell application "Spotify"` would launch it.
final class SpotifyScripting: @unchecked Sendable {
    static let bundleID = "com.spotify.client"

    private let queue = DispatchQueue(label: "com.fonta.dynamicnotch.spotify-script", qos: .userInitiated)
    private var compiled: [String: NSAppleScript] = [:]   // only touched on `queue`

    static var isSpotifyRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { !$0.isTerminated }
    }

    func run<T: Sendable>(_ source: String, cache: Bool = true,
                          parse: @escaping @Sendable (NSAppleEventDescriptor) -> T) async -> Result<T, SpotifyScriptError> {
        await withCheckedContinuation { cont in
            queue.async {
                cont.resume(returning: self.runOnQueue(source, cache: cache, parse: parse))
            }
        }
    }

    func command(_ source: String, cache: Bool = true) async -> Result<Void, SpotifyScriptError> {
        await run(source, cache: cache) { _ in () }
    }

    private func runOnQueue<T>(_ source: String, cache: Bool, parse: (NSAppleEventDescriptor) -> T) -> Result<T, SpotifyScriptError> {
        guard Self.isSpotifyRunning else { return .failure(.notRunning) }
        let script: NSAppleScript
        if cache, let s = compiled[source] {
            script = s
        } else {
            guard let s = NSAppleScript(source: source) else { return .failure(.failed("could not create script")) }
            var err: NSDictionary?
            s.compileAndReturnError(&err)
            if let err { return .failure(Self.error(from: err)) }
            if cache { compiled[source] = s }
            script = s
        }
        var err: NSDictionary?
        let result = script.executeAndReturnError(&err)
        if let err { return .failure(Self.error(from: err)) }
        return .success(parse(result))
    }

    private static func error(from dict: NSDictionary) -> SpotifyScriptError {
        let code = (dict[NSAppleScript.errorNumber] as? Int) ?? 0
        switch code {
        case -1743, -1744: return .permissionDenied
        case -600, -609: return .notRunning
        default: return .failed("\(dict[NSAppleScript.errorMessage] ?? "error") (\(code))")
        }
    }

    // MARK: Scripts

    static let readState = """
    tell application "Spotify"
      set vState to player state as string
      set vPos to 0
      try
        set vPos to player position
      end try
      set vShuffle to shuffling
      set vRepeat to repeating
      set vID to ""
      set vName to ""
      set vArtist to ""
      set vAlbum to ""
      set vDur to 0
      set vArt to ""
      try
        set vTrack to current track
        set vID to id of vTrack
        set vName to name of vTrack
        set vArtist to artist of vTrack
        set vAlbum to album of vTrack
        set vDur to duration of vTrack
        set vArt to artwork url of vTrack
      end try
      return {vState, vPos, vShuffle, vRepeat, vID, vName, vArtist, vAlbum, vDur, vArt}
    end tell
    """

    /// Reads typed values from the returned list, so decimal commas in the user's locale don't matter.
    static func parseState(_ d: NSAppleEventDescriptor) -> SpotifySnapshot {
        func item(_ i: Int) -> NSAppleEventDescriptor? { d.numberOfItems >= i ? d.atIndex(i) : nil }
        let stateText = item(1)?.stringValue ?? "stopped"
        let state = PlayerState(rawValue: stateText) ?? (stateText.contains("play") ? .playing : stateText.contains("paus") ? .paused : .stopped)
        let id = item(5)?.stringValue ?? ""
        var track: SpotifyTrack?
        if !id.isEmpty {
            track = SpotifyTrack(id: id,
                                 name: item(6)?.stringValue ?? "",
                                 artist: item(7)?.stringValue ?? "",
                                 album: item(8)?.stringValue ?? "",
                                 duration: (item(9)?.doubleValue ?? 0) / 1000,
                                 artworkURL: URL(string: item(10)?.stringValue ?? ""))
        }
        return SpotifySnapshot(state: state,
                               position: item(2)?.doubleValue ?? 0,
                               shuffling: item(3)?.booleanValue ?? false,
                               repeating: item(4)?.booleanValue ?? false,
                               track: track)
    }
}
