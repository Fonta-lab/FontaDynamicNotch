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
final class KeyboardBrightnessBackend: BrightnessBackend, @unchecked Sendable {
    private typealias GetIMP = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetIMP = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
    private var client: NSObject?
    private var keyboardID: UInt64?
    private var getIMP: GetIMP?
    private var setIMP: SetIMP?
    private let getSel = NSSelectorFromString("brightnessForKeyboard:")
    private let setSel = NSSelectorFromString("setBrightness:forKeyboard:")

    init() {
        _ = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        guard let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type,
              let gm = class_getInstanceMethod(cls, getSel),
              let sm = class_getInstanceMethod(cls, setSel) else { return }
        let c = cls.init()
        let idsSel = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard c.responds(to: idsSel),
              let ids = c.perform(idsSel)?.takeRetainedValue() as? [NSNumber], let first = ids.first else { return }
        client = c
        keyboardID = first.uint64Value
        getIMP = unsafeBitCast(method_getImplementation(gm), to: GetIMP.self)
        setIMP = unsafeBitCast(method_getImplementation(sm), to: SetIMP.self)
    }

    func probe() -> Bool { get() != nil }

    func get() -> Float? {
        guard let client, let keyboardID, let getIMP else { return nil }
        let v = getIMP(client, getSel, keyboardID)
        return v.isFinite && v >= 0 ? v : nil
    }

    func set(_ value: Float) {
        guard let client, let keyboardID, let setIMP else { return }
        _ = setIMP(client, setSel, max(0, min(1, value)), keyboardID)
    }
}
