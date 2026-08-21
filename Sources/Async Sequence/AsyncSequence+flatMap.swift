extension AsyncSequence {

    @inlinable
    public func flatMap<Segment: AsyncSequence>(
        _ transform: @escaping (Element) -> Segment
    ) -> Async.FlatMap<Self, Segment> {
        Async.FlatMap(base: self, transform: .sync(transform))
    }

    @inlinable
    public func flatMap<Segment: AsyncSequence>(
        _ transform: @escaping (Element) async -> Segment
    ) -> Async.FlatMap<Self, Segment> {
        Async.FlatMap(base: self, transform: .async(transform))
    }
}
