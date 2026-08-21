public import Async_Primitives

extension Async.Stream {

    public struct Iterator: AsyncIteratorProtocol, Sendable {
        @usableFromInline
        let _next: @Sendable () async -> Element?

        @inlinable
        public init(_ next: @escaping @Sendable () async -> Element?) {
            self._next = next
        }
    }
}

extension Async.Stream.Iterator {
    @inlinable
    public func next() async -> Element? {
        await _next()
    }
}
