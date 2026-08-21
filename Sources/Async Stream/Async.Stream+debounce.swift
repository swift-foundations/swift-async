public import Async_Primitives

extension Async.Stream {

    public func debounce(_ duration: Duration) -> Self {
        Self { [self] in
            let state = Async.Stream<Element>.Debounce.State(stream: self, duration: duration)
            return Iterator {
                await state.next()
            }
        }
    }
}
