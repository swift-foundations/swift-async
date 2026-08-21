public import Async_Primitives

extension Async.Stream {

    public func throttle(_ duration: Duration) -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Throttle.State(stream: self, duration: duration)
            return Iterator {
                await state.next()
            }
        }
    }
}
