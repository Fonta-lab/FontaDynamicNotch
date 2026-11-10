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

    @ObservationIgnored private let queue = DispatchQueue(label: "com.fonta.dynamicnotch.brightness", qos: .userInitiated)
    @ObservationIgnored private let screen: BrightnessBackend = DisplayBrightnessBackend()
    @ObservationIgnored private let keyboard: BrightnessBackend = KeyboardBrightnessBackend()

    private init() {}

    func start() {
        let screen = screen, keyboard = keyboard
        queue.async {
            let s = screen.probe() ? screen.get() : nil
            let k = keyboard.probe() ? keyboard.get() : nil
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    let svc = BrightnessService.shared
                    svc.screenAvailable = s != nil
                    svc.keyboardAvailable = k != nil
                    if let s { svc.screenLevel = Double(s) }
                    if let k { svc.keyboardLevel = Double(k) }
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
            guard let v = backend.get() else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { BrightnessService.shared.store(kind, Double(v)) }
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
