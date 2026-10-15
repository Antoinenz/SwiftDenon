import Foundation
import Network
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
    /// The amp doesn't expose its zone names, so they are set locally.
    private(set) var zoneNames: [Int: String] = [:]

    private var receiverName: String?
    private var receiver: (any Receiver)?
    private var listener: Task<Void, Never>?
    private var connector: Task<Void, Never>?
    private var lastVolumeSend = Date.distantPast
    private var pathMonitor: NWPathMonitor?
    private var lastPathSignature = ""

    init() {
        host = UserDefaults.standard.string(forKey: "host") ?? ""
        receiverName = UserDefaults.standard.string(forKey: "name")
        let saved = UserDefaults.standard.dictionary(forKey: "zoneNames") as? [String: String] ?? [:]
        zoneNames = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in Int(k).map { ($0, String(v.prefix(Self.maxZoneNameLength))) } })
        let launchZone = UserDefaults.standard.integer(forKey: "zone") // `-zone 2` launch argument
        if launchZone > 0 { zoneID = launchZone }
    }

    var zone: Zone { state.zone(zoneID) ?? Zone(id: zoneID, name: "Main") }
    /// 0.5 steps are opt-in, and only for zones the receiver reports them for.
    var useHalfSteps: Bool { zone.halfStep && UserDefaults.standard.bool(forKey: "halfStepVolume") }
    /// Keeps the toolbar's zone picker from overflowing.
    static let maxZoneNameLength = 12

    func name(of zone: Zone) -> String { zoneNames[zone.id] ?? zone.name }

    func setZoneName(_ name: String, for id: Int) {
        let trimmed = String(name.trimmingCharacters(in: .whitespaces).prefix(Self.maxZoneNameLength))
        zoneNames[id] = trimmed.isEmpty ? nil : trimmed
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: zoneNames.map { (String($0), $1) }), forKey: "zoneNames")
    }

    /// Runs against an in-memory receiver instead of real hardware.
    var demoMode = UserDefaults.standard.bool(forKey: "demoMode")

    func setDemoMode(_ on: Bool) {
        demoMode = on
        UserDefaults.standard.set(on, forKey: "demoMode")
        zoneID = 1
        start()
    }

    var displayName: String { state.friendlyName ?? receiverName ?? "Receiver" }

    // MARK: Connection

    /// Connects to the saved receiver, or searches the network and connects to the first one found.
    func start() {
        stop()
        let r: any Receiver
        if demoMode {
            r = DemoReceiver()
        } else {
            guard !host.isEmpty else { search(autoConnect: true); return }
            // "address" or "address:port" (port defaults to the receiver's telnet port).
            let parts = host.split(separator: ":", maxSplits: 1).map(String.init)
            r = DenonReceiver(host: parts[0], port: parts.count > 1 ? UInt16(parts[1]) ?? DenonProtocol.port : DenonProtocol.port)
        }
        receiver = r
        listener = Task {
            var checkedWeb = false
            for await s in r.states {
                state = reconcile(s)
                if let n = s.friendlyName, n != receiverName {
                    receiverName = n
                    UserDefaults.standard.set(n, forKey: "name")
                }
                if s.connected, !checkedWeb, !demoMode {
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

    /// Starts over as soon as the network changes while disconnected (joining home Wi-Fi, say),
    /// rather than waiting out the retry backoff. Call once.
    func watchNetwork() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let signature = "\(path.status)-" + path.availableInterfaces.map(\.name).joined(separator: ",")
            Task { @MainActor in
                guard let self, signature != self.lastPathSignature else { return }
                let first = self.lastPathSignature.isEmpty
                self.lastPathSignature = signature
                guard !first, path.status == .satisfied, !self.demoMode, !self.state.connected else { return }
                try? await Task.sleep(for: .seconds(1))   // let DHCP and routes settle
                if !self.state.connected { self.start() }
            }
        }
        monitor.start(queue: .main)
        pathMonitor = monitor
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
        pending.removeAll()
        webUIAvailable = false
    }

    var webUIURL: URL? { URL(string: "http://\(host)/") }

    // MARK: Commands

    func send(_ command: Command) {
        guard let r = receiver else { return }
        Task { try? await r.send(command) }
    }

    func setPower(_ on: Bool) {
        let z = zoneID
        hold("power\(z)", for: 4, matches: { $0.zone(z)?.power == on }) { $0.update(zone: z) { $0.power = on } }
        send(.power(zone: z, on: on))
    }

    func toggleMute() {
        let z = zoneID, m = !zone.mute
        hold("mute\(z)", matches: { $0.zone(z)?.mute == m }) { $0.update(zone: z) { $0.mute = m } }
        send(.mute(zone: z, m))
    }

    /// One step up or down (a whole number), for buttons and keys.
    func stepVolume(by delta: Double) {
        let z = zone
        guard state.connected, z.power else { return }
        setVolume(min(z.maxVolume, max(0, z.volume + delta)), final: true)
    }

    /// Volume change from scrolling. Steps are throttled like slider drags; `final` always sends.
    /// With zero steps and `final`, it just sends the current value so the receiver lands there.
    func scrollVolume(by steps: Double, final: Bool) {
        let z = zone
        guard state.connected, z.power else { return }
        let unit = useHalfSteps ? 0.5 : 1.0
        setVolume(min(z.maxVolume, max(0, z.volume + steps * unit)), final: final)
    }

    func togglePower() {
        guard state.connected else { return }
        setPower(!zone.power)
    }

    /// Steps through the receiver's enabled inputs, wrapping at either end.
    func cycleInput(by offset: Int) {
        let inputs = state.inputs
        guard state.connected, zone.power, !inputs.isEmpty else { return }
        let current = inputs.firstIndex { $0.id == zone.input }
        let next = current.map { ($0 + offset + inputs.count) % inputs.count } ?? 0
        setInput(inputs[next].id)
    }

    /// Selects the zone at `index` in the zone list (0 = Main).
    func selectZone(at index: Int) {
        guard state.zones.indices.contains(index) else { return }
        zoneID = state.zones[index].id
    }

    func cycleZone(by offset: Int) {
        let zones = state.zones
        guard zones.count > 1, let i = zones.firstIndex(where: { $0.id == zoneID }) else { return }
        zoneID = zones[(i + offset + zones.count) % zones.count].id
    }

    func setInput(_ id: String) {
        let z = zoneID
        hold("input\(z)", matches: { $0.zone(z)?.input == id }) { $0.update(zone: z) { $0.input = id } }
        send(.input(zone: z, id))
    }

    /// Slider drags are throttled to ~10 commands/s; the final value is always sent.
    func setVolume(_ raw: Double, final: Bool = false) {
        let z = zoneID
        let v = useHalfSteps ? (raw * 2).rounded() / 2 : raw.rounded()
        hold("volume\(z)", for: 1, matches: { $0.zone(z)?.volume == v }) { $0.update(zone: z) { $0.volume = v } }
        guard final || Date().timeIntervalSince(lastVolumeSend) > 0.1 else { return }
        lastVolumeSend = Date()
        send(.volume(zone: z, v))
    }

    func setBass(_ v: Int) {
        hold("bass", matches: { $0.bass == v }) { $0.bass = v }
        send(.bass(v))
    }
    func setTreble(_ v: Int) {
        hold("treble", matches: { $0.treble == v }) { $0.treble = v }
        send(.treble(v))
    }
    func setSub(_ v: Int) {
        hold("sub", matches: { $0.subLevel == Double(v) }) { $0.subLevel = Double(v) }
        send(.subLevel(Double(v)))
    }
    func setSoundMode(_ m: String) {
        hold("mode", matches: { $0.soundMode == m }) { $0.soundMode = m }
        send(.soundMode(m))
    }
    func setDynamicEQ(_ on: Bool) {
        hold("dyneq", matches: { $0.dynamicEQ == on }) { $0.dynamicEQ = on }
        send(.dynamicEQ(on))
    }
    func setSleep(_ minutes: Int?) {
        hold("sleep", matches: { $0.sleepMinutes == minutes }) { $0.sleepMinutes = minutes }
        send(.sleep(minutes: minutes))
    }

    // MARK: Optimistic updates

    /// A local change shown immediately and kept on screen until the receiver confirms it
    /// (or a timeout passes), so stale status lines in between can't flicker the UI back.
    private struct Pending {
        let expires: Date
        let matches: (ReceiverState) -> Bool
        let apply: (inout ReceiverState) -> Void
    }
    private var pending: [String: Pending] = [:]

    private func hold(_ key: String, for seconds: Double = 1.5,
                      matches: @escaping (ReceiverState) -> Bool,
                      apply: @escaping (inout ReceiverState) -> Void) {
        apply(&state)
        pending[key] = Pending(expires: .now + seconds, matches: matches, apply: apply)
    }

    private func reconcile(_ incoming: ReceiverState) -> ReceiverState {
        var s = incoming
        for (key, p) in pending {
            if p.matches(s) || p.expires < .now { pending[key] = nil } else { p.apply(&s) }
        }
        return s
    }
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
