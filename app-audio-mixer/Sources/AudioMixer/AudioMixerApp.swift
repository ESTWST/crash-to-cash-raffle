import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onQuit: (() -> Void)?
    func applicationWillTerminate(_ notification: Notification) { onQuit?() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AudioMixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var mixer = Mixer()

    var body: some Scene {
        WindowGroup("Audio Mixer") {
            ContentView(mixer: mixer)
                .frame(minWidth: 560, minHeight: 360)
                .onAppear { delegate.onQuit = { mixer.stopAll() } }
        }
    }
}

struct ContentView: View {
    @ObservedObject var mixer: Mixer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Show silent processes", isOn: $mixer.showAll)
                    .onChange(of: mixer.showAll) { _, _ in mixer.refresh() }
                Spacer()
                Button("Open 2nd Chrome profile") { mixer.launchSecondChrome() }
                Button("Refresh") { mixer.refresh() }
                Button("Reset all") { mixer.stopAll() }
            }
            if let e = mixer.error { Text(e).foregroundStyle(.red).font(.caption) }

            if mixer.apps.isEmpty {
                Spacer()
                Text("No apps are playing audio. Start playback somewhere and it will appear here.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(mixer.apps) { app in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(app.name).font(.headline)
                            Text("pid \(app.pid)  \(app.bundleID)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Slider(value: Binding(get: { mixer.volume[app.id] ?? 1 },
                                              set: { mixer.setVolume(app.id, $0) }), in: 0...1)
                            .frame(width: 110)
                        Picker("", selection: Binding(get: { mixer.selection(app.id) },
                                                      set: { mixer.select(app.id, uid: $0) })) {
                            Text("Default (not routed)").tag("")
                            ForEach(mixer.outputs) { Text($0.name).tag($0.uid) }
                        }
                        .labelsHidden().frame(width: 200)
                    }
                }
            }
        }
        .padding()
    }
}
