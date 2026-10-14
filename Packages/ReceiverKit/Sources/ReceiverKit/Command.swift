public enum Command: Sendable, Equatable {
    case power(zone: Int, on: Bool)
    case volume(zone: Int, Double)
    case volumeStep(zone: Int, up: Bool)
    case mute(zone: Int, Bool)
    case input(zone: Int, String)
    case soundMode(String)
    case bass(Int)
    case treble(Int)
    case subLevel(Double)
    case dynamicEQ(Bool)
    case sleep(minutes: Int?)
    case refresh
}
