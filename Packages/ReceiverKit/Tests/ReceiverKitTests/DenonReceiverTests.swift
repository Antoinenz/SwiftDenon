import Foundation
import Network
import Testing
@testable import ReceiverKit

/// Minimal fake AVR: pushes a status burst on connect and records what it receives.
final class MockAVR: @unchecked Sendable {
    let listener = try! NWListener(using: .tcp, on: .any)
    private let lock = NSLock()
    private var _received = ""
    var received: String { lock.withLock { _received } }

    private var open: [NWConnection] = []
    /// Drops every client, as a receiver that went away would.
    func dropClients() { lock.withLock { open.forEach { $0.cancel() }; open.removeAll() } }

    func start() async -> UInt16 {
        listener.newConnectionHandler = { [self] c in
            lock.withLock { open.append(c) }
            c.start(queue: .global())
            c.send(content: Data("ZMON\rMV435\rSIBD\r".utf8), completion: .idempotent)
            func loop() {
                c.receive(minimumIncompleteLength: 1, maximumLength: 1024) { d, _, done, e in
                    if let d { self.lock.withLock { self._received += String(decoding: d, as: UTF8.self) } }
                    if e == nil, !done { loop() }
                }
            }
            loop()
        }
        return await withCheckedContinuation { k in
            listener.stateUpdateHandler = { [listener] s in
                if case .ready = s { k.resume(returning: listener.port!.rawValue); listener.stateUpdateHandler = nil }
            }
            listener.start(queue: .global())
        }
    }
}

final class Seen: @unchecked Sendable {
    private let lock = NSLock()
    private var _connected = false, _ready = false
    var connected: Bool { lock.withLock { _connected } }
    var ready: Bool { lock.withLock { _ready } }
    func record(connected: Bool, ready: Bool) { lock.withLock { _connected = connected; if ready { _ready = true } } }
}

@Suite struct DenonReceiverTests {
    @Test func connectsReceivesStateAndSends() async throws {
        let avr = MockAVR()
        let port = await avr.start()
        let r = DenonReceiver(host: "127.0.0.1", port: port)
        try await r.connect()

        var latest = ReceiverState()
        for await s in r.states {
            latest = s
            if s.zone(1)?.input == "BD" { break }
        }
        #expect(latest.connected)
        #expect(latest.zone(1)?.power == true)
        #expect(latest.zone(1)?.volume == 43.5)

        await r.send(.volume(zone: 1, 30))
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(avr.received.contains("MV30\r"))
        #expect(avr.received.contains("PW?\r")) // refresh on connect
        await r.disconnect()
    }

    @Test func noticesWhenTheReceiverGoesAway() async throws {
        let avr = MockAVR()
        let port = await avr.start()
        let r = DenonReceiver(host: "127.0.0.1", port: port)
        try await r.connect()

        let seen = Seen()
        let states = r.states
        let collector = Task { for await s in states { seen.record(connected: s.connected, ready: s.zone(1)?.input == "BD") } }
        while !seen.ready { try await Task.sleep(nanoseconds: 20_000_000) }
        avr.dropClients()
        // The driver must report the disconnect rather than staying silent.
        for _ in 0..<150 where seen.connected { try await Task.sleep(nanoseconds: 20_000_000) }
        let dropped = !seen.connected
        collector.cancel()
        #expect(dropped)
        await r.disconnect()
    }
}
