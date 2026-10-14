import Foundation
import Observation
import ReceiverKit

@MainActor @Observable
final class ReceiverStore {
    var state = ReceiverState()
    var zoneID = 1
    var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }

    let inputs = DenonProtocol.inputs
    let soundModes = DenonProtocol.soundModes

    private var receiver: DenonReceiver?
    private var listener: Task<Void, Never>?
    private var connector: Task<Void, Never>?
    private var lastVolumeSend = Date.distantPast

    init() { host = UserDefaults.standard.string(forKey: "host") ?? "" }

    var zone: Zone { state.zone(zoneID) ?? Zone(id: zoneID, name: "Main") }

    func start() {
        stop()
        guard !host.isEmpty else { return }
        let r = DenonReceiver(host: host)
        receiver = r
        listener = Task { for await s in r.states { state = s } }
        connector = Task {
            while !Task.isCancelled {
                if (try? await r.connect()) != nil { return }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stop() {
        listener?.cancel(); connector?.cancel()
        if let r = receiver { Task { await r.disconnect() } }
        receiver = nil
        state = ReceiverState()
    }

    func send(_ command: Command) {
        guard let r = receiver else { return }
        Task { await r.send(command) }
    }

    func setPower(_ on: Bool) {
        state.update(zone: zoneID) { $0.power = on }
        send(.power(zone: zoneID, on: on))
    }

    func toggleMute() {
        let m = !zone.mute
        state.update(zone: zoneID) { $0.mute = m }
        send(.mute(zone: zoneID, m))
    }

    func setInput(_ id: String) {
        state.update(zone: zoneID) { $0.input = id }
        send(.input(zone: zoneID, id))
    }

    /// Slider drags are throttled to ~10 commands/s; the final value is always sent.
    func setVolume(_ v: Double, final: Bool = false) {
        state.update(zone: zoneID) { $0.volume = v }
        guard final || Date().timeIntervalSince(lastVolumeSend) > 0.1 else { return }
        lastVolumeSend = Date()
        send(.volume(zone: zoneID, v))
    }
}
