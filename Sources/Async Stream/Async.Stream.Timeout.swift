public import Async_Primitives
internal import Clocks_Dependencies
internal import Ownership_Primitives

extension Async.Stream {

    public func timeout(_ duration: Duration) -> Self {
        Self { [self] in
            let box = Async.Stream<Element>.Iterator.Box(makeAsyncIterator())

            return Iterator {
                @Dependency(\.clock) var clock
                let resolvedClock = clock
                do {
                    return try await withThrowingTaskGroup(of: Element?.self) { group in
                        group.addTask {
                            await box.next()
                        }
                        group.addTask {
                            try await resolvedClock.sleep(
                                until: resolvedClock.now.advanced(by: duration)
                            )
                            throw CancellationError()
                        }

                        if let result = try await group.next() {
                            group.cancelAll()
                            return result
                        }

                        return nil
                    }
                } catch {

                    return nil
                }
            }
        }
    }
}
