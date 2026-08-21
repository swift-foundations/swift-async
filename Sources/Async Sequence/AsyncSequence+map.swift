extension AsyncSequence {

    @inlinable
    public func map<Output>(
        _ transform: @escaping (Element) -> Output
    ) -> Async.Map<Self, Output> {
        Async.Map(base: self, transform: .sync(transform))
    }

    @inlinable
    public func map<Output>(
        _ transform: @escaping (Element) async -> Output
    ) -> Async.Map<Self, Output> {
        Async.Map(base: self, transform: .async(transform))
    }
}
