extension AsyncSequence {

    @inlinable
    public func compactMap<Output>(
        _ transform: @escaping (Element) -> Output?
    ) -> Async.CompactMap<Self, Output> {
        Async.CompactMap(base: self, transform: .sync(transform))
    }

    @inlinable
    public func compactMap<Output>(
        _ transform: @escaping (Element) async -> Output?
    ) -> Async.CompactMap<Self, Output> {
        Async.CompactMap(base: self, transform: .async(transform))
    }
}
