import Foundation
import CoreGraphics
import ObjectiveC

enum BrightnessProbe {
    typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    /// Reads, writes (same value) and reports.
    static func screen() -> String {
        guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) else {
            return "FAIL: DisplayServices could not be loaded"
        }
        guard let g = dlsym(h, "DisplayServicesGetBrightness"), let s = dlsym(h, "DisplayServicesSetBrightness") else {
            return "FAIL: brightness functions not found"
        }
        let get = unsafeBitCast(g, to: GetFn.self)
        let set = unsafeBitCast(s, to: SetFn.self)
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var n: UInt32 = 0
        CGGetActiveDisplayList(8, &ids, &n)
        guard let builtin = ids.prefix(Int(n)).first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            return "No built-in display found (lid closed?)"
        }
        var v: Float = -1
        let r = get(builtin, &v)
        if r != 0 { return "FAIL: read returned error \(r)" }
        let target = max(0.05, v - 0.1)
        let r2 = set(builtin, target)
        var v2: Float = -1
        _ = get(builtin, &v2)
        _ = set(builtin, v)
        return "OK: read \(String(format: "%.2f", v)); set to \(String(format: "%.2f", target)) → read back \(String(format: "%.2f", v2)) (set code \(r2)); restored. The screen should have dimmed briefly."
    }

    static func keyboard() -> String {
        _ = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        guard let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
            return "FAIL: KeyboardBrightnessClient class not found"
        }
        let client = cls.init()
        let idsSel = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard client.responds(to: idsSel) else { return "FAIL: copyKeyboardBacklightIDs missing" }
        guard let ids = client.perform(idsSel)?.takeRetainedValue() as? [NSNumber], let id = ids.first else {
            return "FAIL: no keyboard backlight IDs returned (no backlight on this Mac?)"
        }
        let getSel = NSSelectorFromString("brightnessForKeyboard:")
        guard let m = class_getInstanceMethod(cls, getSel) else { return "FAIL: brightnessForKeyboard: missing" }
        typealias GetIMP = @convention(c) (AnyObject, Selector, UInt64) -> Float
        let get = unsafeBitCast(method_getImplementation(m), to: GetIMP.self)
        let cur = get(client, getSel, id.uint64Value)
        let setSel = NSSelectorFromString("setBrightness:forKeyboard:")
        guard let sm = class_getInstanceMethod(cls, setSel) else { return "FAIL: setBrightness:forKeyboard: missing (read gave \(cur))" }
        typealias SetIMP = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
        let set = unsafeBitCast(method_getImplementation(sm), to: SetIMP.self)
        let target: Float = cur > 0.5 ? 0.2 : 0.8
        let ok = set(client, setSel, target, id.uint64Value)
        let after = get(client, getSel, id.uint64Value)
        _ = set(client, setSel, cur, id.uint64Value)
        return "\(ok ? "OK" : "PARTIAL"): read \(String(format: "%.2f", cur)); set \(String(format: "%.2f", target)) → read back \(String(format: "%.2f", after)); restored. The keyboard light should have changed briefly."
    }
}
