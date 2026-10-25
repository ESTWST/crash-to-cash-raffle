import CoreAudio
import AppKit
import Darwin

func address(_ selector: AudioObjectPropertySelector,
             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func readValue<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                  scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, zero: T) -> T? {
    var addr = address(selector, scope)
    var size = UInt32(MemoryLayout<T>.size)
    var value = zero
    return AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr ? value : nil
}

func readArray<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                  scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [T] {
    var addr = address(selector, scope)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    let count = Int(size) / MemoryLayout<T>.stride
    return [T](unsafeUninitializedCapacity: count) { buf, n in
        var s = size
        let st = AudioObjectGetPropertyData(id, &addr, 0, nil, &s, buf.baseAddress!)
        n = st == noErr ? Int(s) / MemoryLayout<T>.stride : 0
    }
}

func readString(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = address(selector)
    var size = UInt32(MemoryLayout<CFString?>.size)
    var cf: CFString?
    let st = withUnsafeMutablePointer(to: &cf) { AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0) }
    return st == noErr ? cf as String? : nil
}

struct OutputDevice: Identifiable, Hashable {
    let id: AudioObjectID
    let uid: String
    let name: String
}

struct AudioApp: Identifiable, Hashable {
    let id: AudioObjectID      // Core Audio process object
    let pid: pid_t
    let name: String
    let bundleID: String
    let isOutputting: Bool
}

func listOutputDevices() -> [OutputDevice] {
    let ids: [AudioObjectID] = readArray(.system, kAudioHardwarePropertyDevices)
    return ids.compactMap { id in
        let streams: [AudioObjectID] = readArray(id, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
        guard !streams.isEmpty,
              let uid = readString(id, kAudioDevicePropertyDeviceUID),
              let name = readString(id, kAudioObjectPropertyName) else { return nil }
        return OutputDevice(id: id, uid: uid, name: name)
    }
}

func processName(pid: pid_t) -> String {
    if let n = NSRunningApplication(processIdentifier: pid)?.localizedName { return n }
    var buf = [CChar](repeating: 0, count: 256)
    proc_name(pid, &buf, 256)
    let s = String(cString: buf)
    return s.isEmpty ? "pid \(pid)" : s
}

func listAudioApps() -> [AudioApp] {
    let ids: [AudioObjectID] = readArray(.system, kAudioHardwarePropertyProcessObjectList)
    let me = getpid()
    return ids.compactMap { id in
        guard let pid: pid_t = readValue(id, kAudioProcessPropertyPID, zero: 0), pid != me else { return nil }
        let running: UInt32 = readValue(id, kAudioProcessPropertyIsRunningOutput, zero: 0) ?? 0
        return AudioApp(id: id, pid: pid, name: processName(pid: pid),
                        bundleID: readString(id, kAudioProcessPropertyBundleID) ?? "",
                        isOutputting: running != 0)
    }
}

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)
}
