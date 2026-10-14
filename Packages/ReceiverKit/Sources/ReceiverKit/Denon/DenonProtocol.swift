import Foundation

/// Pure encode/decode for the Denon/Marantz ASCII control protocol (telnet, port 23).
public enum DenonProtocol {
    public static let port: UInt16 = 23

    /// Used until the receiver reports its own source list.
    public static let defaultSources: [Input] = [
        ("TV", "TV Audio"), ("SAT/CBL", "Cable / Sat"), ("DVD", "DVD"), ("BD", "Blu-ray"),
        ("GAME", "Game"), ("MPLAY", "Media Player"), ("AUX1", "Aux 1"), ("AUX2", "Aux 2"),
        ("CD", "CD"), ("PHONO", "Phono"), ("TUNER", "Tuner"), ("NET", "HEOS"),
        ("BT", "Bluetooth"), ("USB/IPOD", "USB"), ("8K", "8K"),
    ].map { Input(id: $0.0, name: $0.1) }

    public static func defaultName(for code: String) -> String {
        defaultSources.first { $0.id == code }?.name ?? code
    }

    public static let soundModes = [
        "MOVIE", "MUSIC", "GAME", "DIRECT", "PURE DIRECT", "STEREO", "AUTO",
        "DOLBY DIGITAL", "DTS SURROUND", "MCH STEREO", "VIRTUAL",
    ]

    // MARK: Volume

    /// "50" -> 50, "505" -> 50.5
    public static func parseVolume(_ s: String) -> Double? {
        guard !s.isEmpty, s.allSatisfy(\.isNumber), s.count <= 3 else { return nil }
        guard let n = Double(s) else { return nil }
        return s.count == 3 ? n / 10 : n
    }

    public static func formatVolume(_ v: Double) -> String {
        let half = (max(0, min(98, v)) * 2).rounded() / 2
        let whole = Int(half)
        let base = String(format: "%02d", whole)
        return half == Double(whole) ? base : base + "5"
    }

    // MARK: Encode

    private static func prefix(_ zone: Int) -> String? { zone == 1 ? nil : "Z\(zone)" }

    public static func encode(_ command: Command) -> [String] {
        switch command {
        case let .power(zone, on):
            if zone == 1 { return [on ? "PWON" : "PWSTANDBY"] }
            return ["Z\(zone)" + (on ? "ON" : "OFF")]
        case let .volume(zone, v):
            return [(prefix(zone) ?? "MV") + formatVolume(v)]
        case let .volumeStep(zone, up):
            return [(prefix(zone) ?? "MV") + (up ? "UP" : "DOWN")]
        case let .mute(zone, on):
            return [(prefix(zone).map { $0 + "MU" } ?? "MU") + (on ? "ON" : "OFF")]
        case let .input(zone, code):
            return [(prefix(zone) ?? "SI") + code]
        case let .soundMode(m): return ["MS" + m]
        case let .bass(db): return ["PSBAS " + String(50 + max(-6, min(6, db)))]
        case let .treble(db): return ["PSTRE " + String(50 + max(-6, min(6, db)))]
        case let .subLevel(db): return ["PSSWL " + String(50 + Int(max(-12, min(12, db)).rounded()))]
        case let .dynamicEQ(on): return ["PSDYNEQ " + (on ? "ON" : "OFF")]
        case let .sleep(minutes):
            guard let m = minutes else { return ["SLPOFF"] }
            return ["SLP" + String(format: "%03d", max(1, min(120, m)))]
        case .refresh:
            return ["PW?", "ZM?", "MV?", "MU?", "SI?", "MS?", "Z2?", "Z3?",
                    "PSBAS ?", "PSTRE ?", "PSSWL ?", "PSDYNEQ ?", "SLP?",
                    "SSFUN ?", "SSSOD ?", "NSFRN ?"]
        }
    }

    // MARK: Decode

    /// Applies one status line pushed by the receiver. Returns true if state changed.
    @discardableResult
    public static func apply(_ line: String, to state: inout ReceiverState) -> Bool {
        let before = state
        let l = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if l.hasPrefix("PW") {
            let on = l == "PWON"
            if on || l == "PWSTANDBY" { state.update(zone: 1) { $0.power = on } }
        } else if l == "ZMON" || l == "ZMOFF" {
            state.update(zone: 1) { $0.power = l == "ZMON" }
        } else if l.hasPrefix("MVMAX") {
            if let v = parseVolume(String(l.dropFirst(5)).trimmingCharacters(in: .whitespaces)) {
                state.update(zone: 1) { $0.maxVolume = v }
            }
        } else if l.hasPrefix("MV") {
            if let v = parseVolume(String(l.dropFirst(2))) { state.update(zone: 1) { $0.volume = v } }
        } else if l.hasPrefix("MU") {
            if l == "MUON" || l == "MUOFF" { state.update(zone: 1) { $0.mute = l == "MUON" } }
        } else if l.hasPrefix("SSFUN") {
            // "SSFUNMPLAY Apple TV"
            let body = l.dropFirst(5)
            if body.trimmingCharacters(in: .whitespaces) != "END",
               let sp = body.firstIndex(of: " ") {
                let name = body[sp...].trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { state.sourceNames[String(body[..<sp])] = name }
            }
        } else if l.hasPrefix("SSSOD") {
            // "SSSODBD DEL" = hidden on the receiver
            let parts = l.dropFirst(5).split(separator: " ")
            if parts.count == 2 {
                let code = String(parts[0])
                if !state.sourceOrder.contains(code) { state.sourceOrder.append(code) }
                if parts[1] == "DEL" { state.hiddenSources.insert(code) } else { state.hiddenSources.remove(code) }
            }
        } else if l.hasPrefix("NSFRN ") {
            state.friendlyName = String(l.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if l.hasPrefix("SI") {
            state.update(zone: 1) { $0.input = String(l.dropFirst(2)) }
        } else if l.hasPrefix("MS") {
            state.soundMode = String(l.dropFirst(2))
        } else if l.hasPrefix("PSBAS ") {
            state.bass = Int(l.dropFirst(6)).map { $0 - 50 }
        } else if l.hasPrefix("PSTRE ") {
            state.treble = Int(l.dropFirst(6)).map { $0 - 50 }
        } else if l.hasPrefix("PSSWL ") {
            state.subLevel = Int(l.dropFirst(6)).map { Double($0 - 50) }
        } else if l.hasPrefix("PSDYNEQ ") {
            state.dynamicEQ = l.hasSuffix("ON")
        } else if l.hasPrefix("SLP") {
            let r = l.dropFirst(3)
            state.sleepMinutes = r == "OFF" ? nil : Int(r)
        } else if l.count > 2, l.hasPrefix("Z"), let z = Int(String(l.dropFirst().prefix(1))), (2...3).contains(z) {
            applyZone(z, String(l.dropFirst(2)), to: &state)
        }
        return state != before
    }

    private static func applyZone(_ z: Int, _ r: String, to state: inout ReceiverState) {
        switch r {
        case "ON", "OFF": state.update(zone: z) { $0.power = r == "ON" }
        case "MUON", "MUOFF": state.update(zone: z) { $0.mute = r == "MUON" }
        default:
            if let v = parseVolume(r) {
                state.update(zone: z) { $0.volume = v }
            } else if r.allSatisfy({ $0.isUppercase || $0.isNumber || $0 == "/" }),
                      !r.hasPrefix("PS"), !r.hasPrefix("CS"), !r.hasPrefix("HP"), !["UP", "DOWN"].contains(r) {
                state.update(zone: z) { $0.input = r }
            }
        }
    }
}
