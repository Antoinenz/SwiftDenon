import AppIntents
import ReceiverKit

/// Shortcuts / Siri actions. Each opens a short-lived connection to the saved receiver.
private func withReceiver(_ body: (DenonReceiver) async -> Void) async throws {
    let host = UserDefaults.standard.string(forKey: "host") ?? ""
    guard !host.isEmpty else { throw IntentError.noReceiver }
    let r = DenonReceiver(host: host)
    try await r.connect()
    await body(r)
    try? await Task.sleep(nanoseconds: 150_000_000)
    await r.disconnect()
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case noReceiver
    var localizedStringResource: LocalizedStringResource { "Set up a receiver in SwiftDenon first." }
}

struct SetPowerIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Receiver Power"
    @Parameter(title: "On") var on: Bool

    func perform() async throws -> some IntentResult {
        try await withReceiver { await $0.send(.power(zone: 1, on: on)) }
        return .result()
    }
}

struct SetVolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Receiver Volume"
    @Parameter(title: "Volume", default: 40) var volume: Double

    func perform() async throws -> some IntentResult {
        try await withReceiver { await $0.send(.volume(zone: 1, volume)) }
        return .result()
    }
}

struct SetInputIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Receiver Input"
    @Parameter(title: "Input code", description: "e.g. BD, GAME, TV, NET") var input: String

    func perform() async throws -> some IntentResult {
        try await withReceiver { await $0.send(.input(zone: 1, input.uppercased())) }
        return .result()
    }
}

struct ToggleMuteIntent: AppIntent {
    static let title: LocalizedStringResource = "Mute Receiver"
    @Parameter(title: "Muted", default: true) var muted: Bool

    func perform() async throws -> some IntentResult {
        try await withReceiver { await $0.send(.mute(zone: 1, muted)) }
        return .result()
    }
}
