import Foundation
import Network

public struct DiscoveredReceiver: Identifiable, Hashable, Sendable {
    public var id: String { host }
    public let name: String
    public let host: String
}

/// Finds Denon/Marantz receivers by probing the local /24 for the control port and
/// checking for an AVR-style reply. No names or Bonjour records are guessed.
public enum Discovery {
    public static func scan() -> AsyncStream<DiscoveredReceiver> {
        AsyncStream { cont in
            let task = Task {
                await withTaskGroup(of: DiscoveredReceiver?.self) { group in
                    for host in localSubnetHosts() {
                        group.addTask { await Probe(host: host).run() }
                    }
                    for await r in group { if let r { cont.yield(r) } }
                }
                cont.finish()
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    static func localSubnetHosts() -> [String] {
        var result = Set<String>()
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return [] }
        defer { freeifaddrs(ifap) }
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = p.pointee
            guard let sa = i.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET),
                  i.ifa_flags & UInt32(IFF_UP) != 0, i.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  String(cString: i.ifa_name).hasPrefix("en") else { continue }
            let ip = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let base = ip & 0xFFFF_FF00
            for n in 1...254 where base | UInt32(n) != ip {
                let a = base | UInt32(n)
                result.insert("\(a >> 24).\((a >> 16) & 255).\((a >> 8) & 255).\(a & 255)")
            }
        }
        return Array(result)
    }

    private final class Probe: @unchecked Sendable {
        let host: String
        let conn: NWConnection
        let lock = NSLock()
        var buffer = Data()
        var finished = false
        var cont: CheckedContinuation<DiscoveredReceiver?, Never>?

        init(host: String) {
            self.host = host
            conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: DenonProtocol.port)!, using: .tcp)
        }

        func run() async -> DiscoveredReceiver? {
            await withCheckedContinuation { k in
                cont = k
                conn.stateUpdateHandler = { [self] s in
                    switch s {
                    case .ready:
                        conn.send(content: Data("PW?\rNSFRN ?\r".utf8), completion: .idempotent)
                        receive()
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { self.finish(evaluate: true) }
                    case .failed, .waiting, .cancelled: finish(evaluate: false)
                    default: break
                    }
                }
                conn.start(queue: .global())
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) { self.finish(evaluate: true) }
            }
        }

        func receive() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [self] d, _, done, e in
                if let d { lock.withLock { buffer.append(d) } }
                if e == nil, !done { receive() }
            }
        }

        func finish(evaluate: Bool) {
            let k: CheckedContinuation<DiscoveredReceiver?, Never>? = lock.withLock {
                guard !finished else { return nil }
                finished = true
                defer { cont = nil }
                return cont
            }
            guard let k else { return }
            let data = lock.withLock { buffer }
            conn.cancel()
            k.resume(returning: evaluate ? result(from: data) : nil)
        }

        func result(from data: Data) -> DiscoveredReceiver? {
            let lines = String(decoding: data, as: UTF8.self).split(separator: "\r").map(String.init)
            guard lines.contains(where: { $0.hasPrefix("PW") || $0.hasPrefix("ZM") || $0.hasPrefix("MV") }) else { return nil }
            let name = lines.first { $0.hasPrefix("NSFRN ") }.map { String($0.dropFirst(6)) } ?? "Receiver"
            return DiscoveredReceiver(name: name, host: host)
        }
    }
}
