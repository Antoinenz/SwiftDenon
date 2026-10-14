import Foundation

public struct Input: Hashable, Sendable, Identifiable {
    public let id: String      // protocol code, e.g. "BD"
    public var name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

public struct Zone: Hashable, Sendable, Identifiable {
    public let id: Int         // 1 = main
    public var name: String
    public var power = false
    public var volume: Double = 0   // 0...maxVolume
    public var maxVolume: Double = 98
    public var mute = false
    public var input: String?
    /// Whether the zone takes 0.5 volume steps. Main usually does; Zone 2/3 usually don't.
    /// Learned from the receiver's own 3-digit volume reports.
    public var halfStep: Bool
    public init(id: Int, name: String) { self.id = id; self.name = name; halfStep = id == 1 }
}

public struct ReceiverState: Sendable, Equatable {
    public var zones: [Zone] = [Zone(id: 1, name: "Main")]
    public var soundMode: String?
    public var bass: Int?       // dB offset
    public var treble: Int?
    public var subLevel: Double?
    public var dynamicEQ: Bool?
    public var sleepMinutes: Int?   // nil = off
    public var connected = false
    public var friendlyName: String?
    /// Receiver-configured source names, order and visibility (from SSFUN / SSSOD).
    public var sourceNames: [String: String] = [:]
    public var sourceOrder: [String] = []
    public var hiddenSources: Set<String> = []
    public init() {}

    /// Inputs the user has enabled on the receiver, with the names configured there.
    public var inputs: [Input] {
        let codes = sourceOrder.isEmpty ? DenonProtocol.defaultSources.map(\.id) : sourceOrder
        return codes.filter { !hiddenSources.contains($0) }.map {
            Input(id: $0, name: sourceNames[$0] ?? DenonProtocol.defaultName(for: $0))
        }
    }

    public func zone(_ id: Int) -> Zone? { zones.first { $0.id == id } }

    public mutating func update(zone id: Int, _ change: (inout Zone) -> Void) {
        if let i = zones.firstIndex(where: { $0.id == id }) {
            change(&zones[i])
        } else {
            var z = Zone(id: id, name: "Zone \(id)")
            change(&z)
            zones.append(z)
            zones.sort { $0.id < $1.id }
        }
    }
}
