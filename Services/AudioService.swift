import Foundation
import Observation

/// System volume, mute and output device (SPEC §6). Follows changes made elsewhere through
/// CoreAudio listeners; never polls.
@MainActor @Observable
final class AudioService {
    static let shared = AudioService()

    private(set) var state = AudioSnapshot()
    @ObservationIgnored private let backend = CoreAudioBackend()
    /// Volume to restore when "muting" a device that has no mute switch.
    @ObservationIgnored private var volumeBeforeMute: Float = 0.5

    private init() {}

    var currentDevice: AudioDevice? { state.devices.first { $0.id == state.defaultDeviceID } }
    var isEffectivelyMuted: Bool { state.isMuted || (state.hasVolumeControl && state.volume <= 0.001) }

    func start() {
        backend.onChange = { snap in
            DispatchQueue.main.async { MainActor.assumeIsolated { AudioService.shared.apply(snap) } }
        }
        backend.start()
    }

    private func apply(_ snap: AudioSnapshot) {
        if state != snap { state = snap }
    }

    func setVolume(_ v: Double) {
        state.volume = Float(v)          // instant feedback; the listener confirms
        if v > 0 { state.isMuted = false }
        backend.setVolume(Float(v))
    }

    func toggleMute() {
        if state.canMute {
            state.isMuted.toggle()
            backend.setMuted(state.isMuted)
        } else if state.hasVolumeControl {
            // No mute switch: fall back to volume 0 and back.
            if state.volume > 0.001 {
                volumeBeforeMute = state.volume
                setVolume(0)
            } else {
                setVolume(Double(max(0.05, volumeBeforeMute)))
            }
        }
    }

    func selectDevice(_ id: AudioDevice.ID) {
        state.defaultDeviceID = id
        backend.setDefaultDevice(id)
    }
}
