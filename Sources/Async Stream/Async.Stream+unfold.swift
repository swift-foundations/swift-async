public import Async_Primitives

extension Async.Stream {

    public static func unfold<State: Sendable>(
        _ initial: sending State,
        _ next: @escaping @Sendable (State) async -> (Element, State)?
    ) -> Self {
        let captured = initial
        return Self {
            let state = Async.Stream<Element>.Unfold.State(initial: captured, next: next)
            return Iterator {
                await state.next()
            }
        }
    }
}

extension Async.Stream {

    public static func generate(
        _ generator: @escaping @Sendable () async -> Element?
    ) -> Self {
        Self {
            Iterator {
                if Task.isCancelled { return nil }
                return await generator()
            }
        }
    }
}
