import CoreAudio
import Foundation

final class GainBox { var value: Float = 1.0 }

struct RouteError: LocalizedError {
    let step: String
    let status: OSStatus
    var errorDescription: String? { "\(step) failed (OSStatus \(status))" }
}

/// Captures one process's audio with a Core Audio tap, mutes it on its normal
/// output, and plays it on `outputUID` through a private aggregate device.
final class Route {
    let gain = GainBox()
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "audiomixer.io", qos: .userInteractive)

    init(processObject: AudioObjectID, outputUID: String) throws {
        let desc = CATapDescription(stereoMixdownOfProcesses: [processObject])
        desc.uuid = UUID()
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true

        var st = AudioHardwareCreateProcessTap(desc, &tapID)
        guard st == noErr else { throw RouteError(step: "Create tap (is System Audio Recording permission granted?)", status: st) }

        let dict: [String: Any] = [
            kAudioAggregateDeviceNameKey: "AudioMixer-\(desc.uuid.uuidString.prefix(6))",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: desc.uuid.uuidString,
            ]],
        ]
        st = AudioHardwareCreateAggregateDevice(dict as CFDictionary, &aggID)
        guard st == noErr else { stop(); throw RouteError(step: "Create aggregate device", status: st) }

        let gain = self.gain
        st = AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, queue) { _, inData, _, outData, _ in
            let input = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
            let output = UnsafeMutableAudioBufferListPointer(outData)
            for b in output { if let p = b.mData { memset(p, 0, Int(b.mDataByteSize)) } }
            // Taps are listed after sub-devices, so the tap is the last input buffer.
            guard let inBuf = input.last, let src = inBuf.mData?.assumingMemoryBound(to: Float.self) else { return }
            let inCh = max(Int(inBuf.mNumberChannels), 1)
            let g = gain.value
            for b in output {
                guard let dst = b.mData?.assumingMemoryBound(to: Float.self) else { continue }
                let outCh = max(Int(b.mNumberChannels), 1)
                let frames = min(Int(inBuf.mDataByteSize) / (inCh * 4), Int(b.mDataByteSize) / (outCh * 4))
                for f in 0..<frames {
                    for c in 0..<min(outCh, inCh) { dst[f * outCh + c] = src[f * inCh + c] * g }
                }
            }
        }
        guard st == noErr else { stop(); throw RouteError(step: "Create IO proc", status: st) }
        st = AudioDeviceStart(aggID, procID)
        guard st == noErr else { stop(); throw RouteError(step: "Start device", status: st) }
    }

    func stop() {
        if let p = procID { AudioDeviceStop(aggID, p); AudioDeviceDestroyIOProcID(aggID, p); procID = nil }
        if aggID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggID); aggID = AudioObjectID(kAudioObjectUnknown) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID); tapID = AudioObjectID(kAudioObjectUnknown) }
    }

    deinit { stop() }
}
