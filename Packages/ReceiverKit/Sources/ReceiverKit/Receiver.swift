public protocol Receiver: Sendable {
    var inputs: [Input] { get }
    var soundModes: [String] { get }
    func connect() async throws
    func disconnect() async
    func send(_ command: Command) async throws
    /// Live state updates; the first element is emitted once connected.
    var states: AsyncStream<ReceiverState> { get }
}
