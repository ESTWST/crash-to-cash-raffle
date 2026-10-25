import Foundation
import SwiftUI

@MainActor
final class Mixer: ObservableObject {
    @Published var apps: [AudioApp] = []
    @Published var outputs: [OutputDevice] = []
    @Published var assignment: [AudioObjectID: String] = [:]   // process object -> device UID ("" = untouched)
    @Published var volume: [AudioObjectID: Double] = [:]
    @Published var showAll = false
    @Published var error: String?

    private var routes: [AudioObjectID: Route] = [:]
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        outputs = listOutputDevices()
        let all = listAudioApps()
        let alive = Set(all.map(\.id))
        for id in routes.keys where !alive.contains(id) { clear(id) }
        let routed = Set(routes.keys)
        apps = all.filter { showAll || $0.isOutputting || routed.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func selection(_ id: AudioObjectID) -> String { assignment[id] ?? "" }

    func select(_ id: AudioObjectID, uid: String) {
        error = nil
        clear(id)
        guard !uid.isEmpty else { return }
        do {
            let route = try Route(processObject: id, outputUID: uid)
            route.gain.value = Float(volume[id] ?? 1)
            routes[id] = route
            assignment[id] = uid
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setVolume(_ id: AudioObjectID, _ v: Double) {
        volume[id] = v
        routes[id]?.gain.value = Float(v)
    }

    private func clear(_ id: AudioObjectID) {
        routes[id]?.stop()
        routes[id] = nil
        assignment[id] = nil
    }

    func stopAll() { for id in Array(routes.keys) { clear(id) } }

    /// Chrome shares one audio process per profile, so a second profile gives a separately routable source.
    func launchSecondChrome() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-na", "Google Chrome", "--args", "--user-data-dir=\(NSHomeDirectory())/.audiomixer-chrome2"]
        try? p.run()
    }
}
