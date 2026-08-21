public import Async_Primitives

extension Async.Stream {

    public struct Transducer<Output: Sendable, State: Sendable>: Sendable {

        @usableFromInline
        let initial: @Sendable () -> State

        @usableFromInline
        let step: @Sendable (Element, inout State) -> [Output]

        @usableFromInline
        let complete: @Sendable (inout State) -> [Output]

        @inlinable
        public init(
            initial: @escaping @Sendable () -> State,
            step: @escaping @Sendable (Element, inout State) -> [Output],
            complete: @escaping @Sendable (inout State) -> [Output]
        ) {
            self.initial = initial
            self.step = step
            self.complete = complete
        }
    }
}
