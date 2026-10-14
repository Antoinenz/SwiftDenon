import Foundation
import Observation
import ReceiverKit

@MainActor @Observable
final class ReceiverStore {
    var state = ReceiverState()
    var zoneID = 1
    var discovered: [DiscoveredReceiver] = []
    var scanning = false
    var webUIAvailable = false
    private(set) var host: String

    private var receiverName: String?
    private var receiver: DenonReceiver?
    private var listener: Task<Void, Never>?
    private var connector: Task<Void, Never>?
    private var lastVolumeSend = Date.distantPast

    init() {
        host = UserDefaults.standard.string(forKey: "host") ?? ""
        receiverName = UserDefaults.standard.string(forKey: "name")
        let launchZone = UserDefaults.standard.integer(forKey: "zone") // `-zone 2` launch argument
        if launchZone > 0 { zoneID = launchZone }
    }

    var zone: Zone { state.zone(zoneID) ?? Zone(id: zoneID, name: "Main") }
    /// 0.5 steps are opt-in, and only for zones the receiver reports them for.
    var useHalfSteps: Bool { zone.halfStep && UserDefaults.standard.bool(forKey: "halfStepVolume") }
    var displayName: String { state.friendlyName ?? receiverName ?? "Receiver" }

    // MARK: Connection

    /// Connects to the saved receiver, or searches the network and connects to the first one found.
    func start() {
        stop()
        guard !host.isEmpty else { search(autoConnect: true); return }
        let r = DenonReceiver(host: host)
        receiver = r
        listener = Task {
            var checkedWeb = false
            for await s in r.states {
                state = s
                if let n = s.friendlyName, n != receiverName {
                    receiverName = n
                    UserDefaults.standard.set(n, forKey: "name")
                }
                if s.connected, !checkedWeb {
                    checkedWeb = true
                    webUIAvailable = await WebUI.isAvailable(host: host)
                }
            }
        }
        connector = Task {
            var failures = 0
            while !Task.isCancelled {
                if (try? await r.connect()) != nil { return }
                failures += 1
                // The amp may have a new DHCP address: look for it again.
                if failures == 3 { search(autoConnect: true, replacing: true) }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func select(host newHost: String) {
        host = newHost
        UserDefaults.standard.set(newHost, forKey: "host")
        start()
    }

    func search(autoConnect: Bool = false, replacing: Bool = false) {
        guard !scanning else { return }
        scanning = true
        Task {
            var connect = autoConnect
            for await r in Discovery.scan() {
                if !discovered.contains(r) { discovered.append(r) }
                if connect, !replacing || r.name == receiverName {
                    connect = false
                    select(host: r.host)
                }
            }
            scanning = false
        }
    }

    func stop() {
        listener?.cancel(); connector?.cancel()
        if let r = receiver { Task { await r.disconnect() } }
        receiver = nil
        state = ReceiverState()
        webUIAvailable = false
    }

    var webUIURL: URL? { URL(string: "http://\(host)/") }

    // MARK: Commands

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
    func setVolume(_ raw: Double, final: Bool = false) {
        let v = useHalfSteps ? (raw * 2).rounded() / 2 : raw.rounded()
        state.update(zone: zoneID) { $0.volume = v }
        guard final || Date().timeIntervalSince(lastVolumeSend) > 0.1 else { return }
        lastVolumeSend = Date()
        send(.volume(zone: zoneID, v))
    }

    func setBass(_ v: Int) { state.bass = v; send(.bass(v)) }
    func setTreble(_ v: Int) { state.treble = v; send(.treble(v)) }
    func setSub(_ v: Int) { state.subLevel = Double(v); send(.subLevel(Double(v))) }
}

/// The receiver's built-in web interface, when it answers on port 80.
enum WebUI {
    private final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(_ s: URLSession, task: URLSessionTask, willPerformHTTPRedirection r: HTTPURLResponse,
                        newRequest: URLRequest) async -> URLRequest? { nil }
    }

    static func isAvailable(host: String) async -> Bool {
        guard let url = URL(string: "http://\(host)/") else { return false }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "HEAD"
        guard let (_, resp) = try? await URLSession.shared.data(for: req, delegate: NoRedirect()),
              let code = (resp as? HTTPURLResponse)?.statusCode else { return false }
        return code < 400
    }
}
