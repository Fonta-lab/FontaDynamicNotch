import Foundation
import Observation

/// Screen and keyboard brightness. Each is feature-flagged: if its private API doesn't work,
/// `…Available` stays false and the button is removed from the notch (SPEC §13).
/// Values are re-read when a slider appears; there is no polling.
@MainActor @Observable
final class BrightnessService {
    static let shared = BrightnessService()

    enum Kind: Sendable { case screen, keyboard }

    private(set) var screenAvailable = false
    private(set) var keyboardAvailable = false
    private(set) var screenLevel: Double = 0.5
    private(set) var keyboardLevel: Double = 0.5
    /// macOS has turned the keyboard light off because the room is bright (see KeyboardBrightnessBackend).
    private(set) var keyboardSuppressed = false

    @ObservationIgnored private let queue = DispatchQueue(label: "com.fonta.dynamicnotch.brightness", qos: .userInitiated)
    @ObservationIgnored private let screen: BrightnessBackend = DisplayBrightnessBackend()
    @ObservationIgnored private let keyboard: BrightnessBackend = KeyboardBrightnessBackend()

    private init() {}

    func start() {
        probe(retryKeyboard: true)
    }

    /// Checks which controls work. The keyboard backlight service can be slow to appear at login,
    /// so if it isn't there yet it's checked once more a few seconds later.
    private func probe(retryKeyboard: Bool) {
        let screen = screen, keyboard = keyboard
        queue.async {
            let s = screen.probe() ? screen.get() : nil
            let kOK = keyboard.probe()
            let k = kOK ? keyboard.get() : nil
            let kSuppressed = kOK && keyboard.isSuppressed()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let svc = BrightnessService.shared
                    svc.screenAvailable = s != nil
                    svc.keyboardAvailable = kOK
                    if let s { svc.screenLevel = Double(s) }
                    if let k { svc.keyboardLevel = Double(k) }
                    svc.keyboardSuppressed = kSuppressed
                    if !kOK && retryKeyboard {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            MainActor.assumeIsolated { BrightnessService.shared.probe(retryKeyboard: false) }
                        }
                    }
                }
            }
        }
    }

    func available(_ kind: Kind) -> Bool { kind == .screen ? screenAvailable : keyboardAvailable }
    func level(_ kind: Kind) -> Double { kind == .screen ? screenLevel : keyboardLevel }

    /// Re-reads the current value (it may have changed with the keyboard keys).
    func refresh(_ kind: Kind) {
        let backend = backend(kind)
        queue.async {
            let v = backend.get()
            let suppressed = backend.isSuppressed()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let svc = BrightnessService.shared
                    if let v { svc.store(kind, Double(v)) }
                    if kind == .keyboard, svc.keyboardSuppressed != suppressed { svc.keyboardSuppressed = suppressed }
                }
            }
        }
    }

    func set(_ kind: Kind, _ value: Double) {
        store(kind, value)
        let backend = backend(kind)
        queue.async { backend.set(Float(value)) }
    }

    private func store(_ kind: Kind, _ v: Double) {
        if kind == .screen { screenLevel = v } else { keyboardLevel = v }
    }

    private func backend(_ kind: Kind) -> BrightnessBackend { kind == .screen ? screen : keyboard }
}
