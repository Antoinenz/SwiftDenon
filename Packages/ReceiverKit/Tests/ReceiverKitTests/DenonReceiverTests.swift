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

    func start() async -> UInt16 {
        listener.newConnectionHandler = { [self] c in
            c.start(queue: .global())
            c.send(content: Data("PWON\rMV435\rSIBD\r".utf8), completion: .idempotent)
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
}
