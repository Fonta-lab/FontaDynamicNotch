import AVFoundation
import Observation

/// Plays the alarm sound on a loop until Stop (SPEC §7.4). One sound for the whole app,
/// however many screens show the alarm.
@MainActor @Observable
final class AlarmService {
    static let shared = AlarmService()

    private(set) var isRinging = false
    /// Tells the screens to open / release the notch.
    @ObservationIgnored var onRingingChanged: ((Bool) -> Void)?
    @ObservationIgnored private let player = AlarmPlayer()

    private init() {}

    func ring(names: [String]) {
        if !isRinging {
            isRinging = true
            let s = SettingsStore.shared.settings
            player.start(url: s.alarmSound.url, volume: Float(s.alarmVolume)) { ok in
                guard !ok else { return }
                // Couldn't play (e.g. no output device): fall back to a notification.
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        NotificationService.shared.post(title: "⏲ \(names.joined(separator: ", ")) ended", body: "The alarm sound couldn't play.")
                    }
                }
            }
            onRingingChanged?(true)
        }
    }

    /// Stop from any screen stops it everywhere.
    func stop() {
        guard isRinging else { return }
        isRinging = false
        player.stop()
        TimerStore.shared.clearRinging()
        onRingingChanged?(false)
    }
}

/// Owns the AVAudioPlayer on its own queue (loading the file is disk I/O).
final class AlarmPlayer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.fonta.dynamicnotch.alarm", qos: .userInitiated)
    private var player: AVAudioPlayer?   // only touched on `queue`

    func start(url: URL, volume: Float, loop: Bool = true, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async {
            self.player?.stop()
            guard let p = try? AVAudioPlayer(contentsOf: url) else {
                self.player = nil
                completion(false)
                return
            }
            p.numberOfLoops = loop ? -1 : 0
            p.volume = max(0, min(1, volume))
            let ok = p.play()
            self.player = ok ? p : nil
            completion(ok)
        }
    }

    func stop() {
        queue.async {
            self.player?.stop()
            self.player = nil
        }
    }
}
