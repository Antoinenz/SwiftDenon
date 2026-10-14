public protocol Receiver: Sendable {
    var soundModes: [String] { get }
    func connect() async throws
    func disconnect() async
    func send(_ command: Command) async throws
    /// Live state updates; the first element is emitted once connected.
    var states: AsyncStream<ReceiverState> { get }
}
