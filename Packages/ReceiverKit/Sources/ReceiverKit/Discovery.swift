import Foundation
import Network

public struct DiscoveredReceiver: Identifiable, Hashable, Sendable {
    public var id: String { host }
    public let name: String
    public let host: String
}

/// Finds Denon/Marantz receivers on the LAN via Bonjour and resolves them to IPv4 addresses.
public enum Discovery {
    private final class Seen: @unchecked Sendable {
        private let lock = NSLock()
        private var names = Set<String>()
        func insert(_ n: String) -> Bool { lock.withLock { names.insert(n).inserted } }
    }

    static func looksLikeAVR(_ name: String) -> Bool {
        let n = name.lowercased()
        return ["denon", "marantz", "avr", "heos"].contains { n.contains($0) }
    }

    public static func stream() -> AsyncStream<DiscoveredReceiver> {
        AsyncStream { cont in
            let seen = Seen()
            let browsers = ["_heos-audio._tcp", "_http._tcp"].map {
                NWBrowser(for: .bonjour(type: $0, domain: nil), using: .tcp)
            }
            for b in browsers {
                b.browseResultsChangedHandler = { results, _ in
                    for r in results {
                        guard case let .service(name, _, _, _) = r.endpoint,
                              looksLikeAVR(name), seen.insert(name) else { continue }
                        resolve(r.endpoint, name: name) { cont.yield($0) }
                    }
                }
                b.start(queue: .global())
            }
            cont.onTermination = { _ in browsers.forEach { $0.cancel() } }
        }
    }

    private static func resolve(_ endpoint: NWEndpoint, name: String,
                                found: @escaping @Sendable (DiscoveredReceiver) -> Void) {
        let c = NWConnection(to: endpoint, using: .tcp)
        c.stateUpdateHandler = { [c] state in
            switch state {
            case .ready:
                if case let .hostPort(host, _)? = c.currentPath?.remoteEndpoint, case let .ipv4(addr) = host {
                    let ip = "\(addr)".split(separator: "%").first.map(String.init) ?? "\(addr)"
                    found(DiscoveredReceiver(name: name, host: ip))
                }
                c.cancel()
            case .failed: c.cancel()
            default: break
            }
        }
        c.start(queue: .global())
    }
}
