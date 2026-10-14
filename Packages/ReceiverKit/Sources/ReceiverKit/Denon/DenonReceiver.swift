import Foundation
import Network

/// Denon/Marantz receiver over the telnet-style control port.
/// The receiver pushes status lines, so state is live without polling.
public actor DenonReceiver: Receiver {
    public nonisolated let soundModes = DenonProtocol.soundModes
    public nonisolated let states: AsyncStream<ReceiverState>

    private let host: String
    private let port: UInt16
    private let continuation: AsyncStream<ReceiverState>.Continuation
    private var state = ReceiverState()
    private var connection: NWConnection?
    private var pending: CheckedContinuation<Void, Error>?
    private var buffer = Data()
    private var wantConnected = false
    private var reconnecting = false

    public init(host: String, port: UInt16 = DenonProtocol.port) {
        self.host = host
        self.port = port
        (states, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    // MARK: Lifecycle

    public func connect() async throws {
        wantConnected = true
        try await open()
    }

    public func disconnect() {
        wantConnected = false
        connection?.cancel()
        connection = nil
        setConnected(false)
    }

    private func open() async throws {
        connection?.cancel()
        buffer.removeAll()
        let c = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        connection = c
        c.stateUpdateHandler = { [weak self] s in
            guard let self else { return }
            Task { await self.handle(s, from: c) }
        }
        // .waiting is transient (e.g. Local Network permission pending); give it time before failing.
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            if connection === c, pending != nil { c.cancel() }
        }
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            pending = k
            c.start(queue: .global(qos: .userInitiated))
        }
    }

    private func handle(_ s: NWConnection.State, from c: NWConnection) async {
        guard c === connection else { return }
        switch s {
        case .ready:
            pending?.resume(); pending = nil
            setConnected(true)
            receive(on: c)
            await send(.refresh)
        case .failed(let e):
            c.cancel()
            fail(e)
        case .cancelled:
            fail(CancellationError())
        default:
            break
        }
    }

    private func fail(_ error: Error) {
        setConnected(false)
        if let k = pending { pending = nil; k.resume(throwing: error); return }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard wantConnected, !reconnecting else { return }
        reconnecting = true
        Task {
            var delay: UInt64 = 1
            while wantConnected {
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                if !wantConnected { break }
                if (try? await open()) != nil { break }
                delay = min(delay * 2, 10)
            }
            reconnecting = false
        }
    }

    // MARK: IO

    private nonisolated func receive(on c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, done, error in
            guard let self else { return }
            Task {
                if let data { await self.consume(data) }
                if error == nil, !done { self.receive(on: c) }
            }
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        var changed = false
        while let i = buffer.firstIndex(of: 13) {
            let line = String(decoding: buffer[buffer.startIndex..<i], as: UTF8.self)
            buffer.removeSubrange(buffer.startIndex...i)
            if DenonProtocol.apply(line, to: &state) { changed = true }
        }
        if changed { continuation.yield(state) }
    }

    private func setConnected(_ on: Bool) {
        guard state.connected != on else { return }
        state.connected = on
        continuation.yield(state)
    }

    public func send(_ command: Command) async {
        for line in DenonProtocol.encode(command) {
            connection?.send(content: Data((line + "\r").utf8), completion: .idempotent)
            try? await Task.sleep(nanoseconds: 50_000_000) // AVRs drop commands sent faster than ~50 ms
        }
    }
}
