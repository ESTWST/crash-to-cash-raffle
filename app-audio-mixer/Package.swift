// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AudioMixer",
    platforms: [.macOS("14.2")],
    targets: [
        .executableTarget(name: "AudioMixer", path: "Sources/AudioMixer")
    ]
)
