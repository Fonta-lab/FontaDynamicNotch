import CoreAudio
import AudioToolbox
import Foundation

struct AudioDevice: Identifiable, Equatable, Sendable {
    let id: AudioDeviceID
    let name: String
    let symbol: String   // SF Symbol for the device type
}

struct AudioSnapshot: Equatable, Sendable {
    var devices: [AudioDevice] = []
    var defaultDeviceID: AudioDeviceID = 0
    var volume: Float = 0
    var isMuted = false
    var hasVolumeControl = false
    var canMute = false
}

/// All CoreAudio calls run on one serial background queue; results are delivered as snapshots.
/// Listeners (no polling) fire on device-list, default-device, volume and mute changes.
final class CoreAudioBackend: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.fonta.dynamicnotch.audio", qos: .userInitiated)
    var onChange: (@Sendable (AudioSnapshot) -> Void)?

    // Only touched on `queue`
    private var listenedDevice: AudioDeviceID = 0
    private var deviceBlock: AudioObjectPropertyListenerBlock?

    private static let watchedDeviceProps: [(AudioObjectPropertySelector, AudioObjectPropertyScope)] = [
        (kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput),
        (kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput),
    ]

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.refresh() }
            for sel in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
                var a = Self.address(sel)
                AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, self.queue, block)
            }
            self.refresh()
        }
    }

    func setVolume(_ v: Float) {
        queue.async {
            let id = Self.defaultOutputDevice()
            var value = max(0, min(1, v))
            var a = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)
            guard AudioObjectHasProperty(id, &a) else { return }
            AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
            // Unmute when the user raises the volume, like the system does.
            if value > 0, Self.isMuted(id) == true { Self.setMute(id, false) }
        }
    }

    func setMuted(_ muted: Bool) {
        queue.async { Self.setMute(Self.defaultOutputDevice(), muted) }
    }

    func setDefaultDevice(_ id: AudioDeviceID) {
        queue.async {
            var dev = id
            var a = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil,
                                       UInt32(MemoryLayout<AudioDeviceID>.size), &dev)
        }
    }

    // MARK: On queue

    private func refresh() {
        let def = Self.defaultOutputDevice()
        if def != listenedDevice { moveDeviceListeners(to: def) }
        var snap = AudioSnapshot()
        snap.defaultDeviceID = def
        snap.devices = Self.outputDevices()
        var va = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)
        snap.hasVolumeControl = AudioObjectHasProperty(def, &va) && Self.isSettable(def, va)
        snap.volume = Self.get(def, va, Float32(0)) ?? 0
        var ma = Self.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
        snap.canMute = AudioObjectHasProperty(def, &ma) && Self.isSettable(def, ma)
        snap.isMuted = Self.isMuted(def) ?? false
        onChange?(snap)
    }

    private func moveDeviceListeners(to id: AudioDeviceID) {
        if listenedDevice != 0, let block = deviceBlock {
            for (sel, scope) in Self.watchedDeviceProps {
                var a = Self.address(sel, scope)
                AudioObjectRemovePropertyListenerBlock(listenedDevice, &a, queue, block)
            }
        }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.refresh() }
        for (sel, scope) in Self.watchedDeviceProps {
            var a = Self.address(sel, scope)
            if AudioObjectHasProperty(id, &a) { AudioObjectAddPropertyListenerBlock(id, &a, queue, block) }
        }
        deviceBlock = block
        listenedDevice = id
    }

    // MARK: Helpers

    private static func address(_ sel: AudioObjectPropertySelector,
                                _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func get<T: BitwiseCopyable>(_ id: AudioObjectID, _ addr: AudioObjectPropertyAddress, _ initial: T) -> T? {
        var a = addr
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &value) { buf in
            AudioObjectGetPropertyData(id, &a, 0, nil, &size, buf.baseAddress!)
        }
        return status == noErr ? value : nil
    }

    private static func isSettable(_ id: AudioObjectID, _ addr: AudioObjectPropertyAddress) -> Bool {
        var a = addr
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(id, &a, &settable) == noErr && settable.boolValue
    }

    private static func defaultOutputDevice() -> AudioDeviceID {
        get(AudioObjectID(kAudioObjectSystemObject), address(kAudioHardwarePropertyDefaultOutputDevice), AudioDeviceID(0)) ?? 0
    }

    private static func isMuted(_ id: AudioDeviceID) -> Bool? {
        get(id, address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput), UInt32(0)).map { $0 != 0 }
    }

    private static func setMute(_ id: AudioDeviceID, _ muted: Bool) {
        var v: UInt32 = muted ? 1 : 0
        var a = address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
        guard AudioObjectHasProperty(id, &a) else { return }
        AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v)
    }

    private static func outputDevices() -> [AudioDevice] {
        var a = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let sys = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(sys, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard hasOutputStreams(id), !(get(id, address(kAudioDevicePropertyIsHidden), UInt32(0)).map { $0 != 0 } ?? false) else { return nil }
            let name = deviceName(id)
            let transport = get(id, address(kAudioDevicePropertyTransportType), UInt32(0)) ?? 0
            return AudioDevice(id: id, name: name, symbol: symbol(name: name, transport: transport))
        }
    }

    private static func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var a = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr && size > 0
    }

    private static func deviceName(_ id: AudioDeviceID) -> String {
        var a = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &name) == noErr, let n = name else { return "Unknown" }
        return n.takeRetainedValue() as String
    }

    private static func symbol(name: String, transport: UInt32) -> String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        if n.contains("homepod") { return "homepod" }
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: return "laptopcomputer"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "display"
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeThunderbolt: return "cable.connector"
        default: return "hifispeaker"
        }
    }
}
