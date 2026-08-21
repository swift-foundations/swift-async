public import Async_Primitives

extension Async.Stream {

    public func first() -> Self {
        prefix(1)
    }

    public func first(
        where predicate: @escaping @Sendable (Element) -> Bool
    ) -> Self {
        filter(predicate).first()
    }
}
