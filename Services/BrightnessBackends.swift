import Foundation
import CoreGraphics
import ObjectiveC

/// A brightness control that may not exist on this Mac / macOS version (SPEC §13).
/// Implementations use private APIs; every call is safe to make even when unavailable.
protocol BrightnessBackend: AnyObject, Sendable {
    /// Checks once whether the API works here. Called off the main thread.
    func probe() -> Bool
    func get() -> Float?
    func set(_ value: Float)
}

/// Built-in display brightness via DisplayServices (private framework).
final class DisplayBrightnessBackend: BrightnessBackend, @unchecked Sendable {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private var getFn: GetFn?
    private var setFn: SetFn?

    init() {
        guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let g = dlsym(h, "DisplayServicesGetBrightness"),
              let s = dlsym(h, "DisplayServicesSetBrightness") else { return }
        getFn = unsafeBitCast(g, to: GetFn.self)
        setFn = unsafeBitCast(s, to: SetFn.self)
    }

    private var builtinDisplay: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var n: UInt32 = 0
        guard CGGetActiveDisplayList(16, &ids, &n) == .success else { return nil }
        return ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    func probe() -> Bool { get() != nil }

    func get() -> Float? {
        guard let getFn, let id = builtinDisplay else { return nil }
        var v: Float = -1
        return getFn(id, &v) == 0 && v >= 0 ? v : nil
    }

    func set(_ value: Float) {
        guard let setFn, let id = builtinDisplay else { return }
        _ = setFn(id, max(0, min(1, value)))
    }
}

/// Keyboard backlight via CoreBrightness's KeyboardBrightnessClient (private framework).
/// Sturdier since v0.4 (a tester on macOS 15 reported it not working in v0.2):
/// - uses the built-in keyboard's ID (`isKeyboardBuiltIn:`), not just the first one listed;
/// - sets with `setBrightness:fadeSpeed:commit:forKeyboard:` (commits like the brightness keys),
///   falling back to `setBrightness:forKeyboard:` if that's missing or refuses;
/// - reads `brightnessForKeyboard:` (0…1; it reads 0 while the light is off or idle-dimmed — setting
///   from there still works, so the control is never disabled for it);
/// - the client and IDs are looked up when probed (and again on later probes if they weren't ready).
final class KeyboardBrightnessBackend: BrightnessBackend, @unchecked Sendable {
    private typealias FloatIMP = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias BoolIMP = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    private typealias SetIMP = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
    private typealias SetCommitIMP = @convention(c) (AnyObject, Selector, Float, Int32, Bool, UInt64) -> Bool

    private let getSel = NSSelectorFromString("brightnessForKeyboard:")
    private let builtInSel = NSSelectorFromString("isKeyboardBuiltIn:")
    private let setSel = NSSelectorFromString("setBrightness:forKeyboard:")
    private let setCommitSel = NSSelectorFromString("setBrightness:fadeSpeed:commit:forKeyboard:")
    private let idsSel = NSSelectorFromString("copyKeyboardBacklightIDs")

    private var cls: NSObject.Type?
    private var client: NSObject?
    private var keyboardID: UInt64?

    init() {
        _ = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
    }

    private func imp<T>(_ sel: Selector, _: T.Type) -> T? {
        guard let cls, let m = class_getInstanceMethod(cls, sel) else { return nil }
        return unsafeBitCast(method_getImplementation(m), to: T.self)
    }

    /// Finds the client and the built-in keyboard's ID (once they exist).
    private func resolve() -> Bool {
        if client != nil, keyboardID != nil { return true }
        guard let cls else { return false }
        let c = client ?? cls.init()
        client = c
        guard c.responds(to: idsSel),
              let ids = c.perform(idsSel)?.takeRetainedValue() as? [NSNumber], !ids.isEmpty else { return false }
        let all = ids.map(\.uint64Value)
        if let isBuiltIn = imp(builtInSel, BoolIMP.self) {
            keyboardID = all.first { isBuiltIn(c, builtInSel, $0) } ?? all[0]
        } else {
            keyboardID = all[0]
        }
        return true
    }

    private var canSet: Bool {
        imp(setCommitSel, SetCommitIMP.self) != nil || imp(setSel, SetIMP.self) != nil
    }

    /// Available when the client, a keyboard and a way to set it exist. Reading the level may fail
    /// on some versions without that making the control useless.
    func probe() -> Bool { resolve() && canSet }

    func get() -> Float? {
        guard resolve(), let client, let keyboardID else { return nil }
        guard let f = imp(getSel, FloatIMP.self) else { return nil }
        let v = f(client, getSel, keyboardID)
        return v.isFinite && v >= 0 && v <= 1 ? v : nil
    }

    func set(_ value: Float) {
        guard resolve(), let client, let keyboardID else { return }
        let v = max(0, min(1, value))
        if let setCommit = imp(setCommitSel, SetCommitIMP.self), setCommit(client, setCommitSel, v, 0, true, keyboardID) {
            return
        }
        if let set = imp(setSel, SetIMP.self) { _ = set(client, setSel, v, keyboardID) }
    }
}
