import Foundation

/// A receiver that lives entirely in memory, for trying the app without hardware.
public actor DemoReceiver: Receiver {
    public nonisolated let soundModes = DenonProtocol.soundModes
    public nonisolated let states: AsyncStream<ReceiverState>
    private let continuation: AsyncStream<ReceiverState>.Continuation
    private var state: ReceiverState

    public init() {
        (states, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        var s = ReceiverState()
        s.friendlyName = "Demo Receiver"
        s.sourceNames = ["MPLAY": "Apple TV", "GAME": "Game Console", "BD": "Blu-ray", "TV": "TV Audio", "SAT/CBL": "Cable"]
        s.sourceOrder = ["MPLAY", "GAME", "BD", "TV", "SAT/CBL"]
        s.soundMode = "DOLBY DIGITAL"
        s.bass = 0; s.treble = 0; s.subLevel = 0
        s.dynamicEQ = false
        s.update(zone: 1) { $0.power = true; $0.volume = 35; $0.halfStep = true; $0.input = "MPLAY" }
        s.update(zone: 2) { $0.volume = 30; $0.input = "TV" }
        state = s
    }

    public func connect() async throws {
        state.connected = true
        continuation.yield(state)
    }

    public func disconnect() async {
        state.connected = false
        continuation.yield(state)
        continuation.finish()
    }

    public func send(_ command: Command) async {
        switch command {
        case let .power(z, on): state.update(zone: z) { $0.power = on }
        case let .volume(z, v): state.update(zone: z) { $0.volume = min($0.maxVolume, max(0, v)) }
        case let .volumeStep(z, up):
            state.update(zone: z) { $0.volume = min($0.maxVolume, max(0, $0.volume + (up ? 1 : -1))) }
        case let .mute(z, on): state.update(zone: z) { $0.mute = on }
        case let .input(z, code): state.update(zone: z) { $0.input = code }
        case let .soundMode(m): state.soundMode = m
        case let .bass(v): state.bass = v
        case let .treble(v): state.treble = v
        case let .subLevel(v): state.subLevel = v
        case let .dynamicEQ(on): state.dynamicEQ = on
        case let .sleep(m): state.sleepMinutes = m
        case .refresh: break
        }
        continuation.yield(state)
    }
}
