public import Async_Primitives

extension Async.Stream {

    public func last() -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Last.State(stream: self)
            return Iterator {
                await state.next()
            }
        }
    }

    public func last(
        where predicate: @escaping @Sendable (Element) -> Bool
    ) -> Self {
        filter(predicate).last()
    }
}
