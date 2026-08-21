public import Async_Primitives
internal import Clocks_Dependencies
internal import Ownership_Primitives

extension Async.Stream {

    public func delay(_ duration: Duration) -> Self {
        Self { [self] in
            let box = Async.Stream<Element>.Iterator.Box(makeAsyncIterator())
            return Iterator {
                @Dependency(\.clock) var clock
                guard let element = await box.next() else { return nil }

                try? await clock.sleep(for: duration)
                if Task.isCancelled { return nil }
                return element
            }
        }
    }
}
