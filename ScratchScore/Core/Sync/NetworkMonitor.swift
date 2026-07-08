import Foundation
import Network
import Observation

/// Observes connectivity so the sync engine can drain its push queue when a path
/// becomes available.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOnline: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.scratchscore.network")

    /// Called on the main actor each time connectivity transitions to online.
    var onBecameOnline: (() -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = online
                if online && wasOffline { self.onBecameOnline?() }
            }
        }
        monitor.start(queue: queue)
    }

    func stop() { monitor.cancel() }
}
