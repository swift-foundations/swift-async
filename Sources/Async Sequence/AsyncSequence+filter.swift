extension AsyncSequence {

    @inlinable
    public func filter(
        _ isIncluded: @escaping (Element) -> Bool
    ) -> Async.Filter<Self> {
        Async.Filter(base: self, predicate: .sync(isIncluded))
    }

    @inlinable
    public func filter(
        _ isIncluded: @escaping (Element) async -> Bool
    ) -> Async.Filter<Self> {
        Async.Filter(base: self, predicate: .async(isIncluded))
    }
}
