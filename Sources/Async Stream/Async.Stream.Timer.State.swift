public import Async_Primitives
internal import Clocks_Dependencies

extension Async.Stream.Timer where Element == Void {

    @usableFromInline
    actor State {
        @usableFromInline
        let delay: Duration

        @usableFromInline
        var fired: Bool = false

        @usableFromInline
        init(delay: Duration) {
            self.delay = delay
        }
    }
}

extension Async.Stream.Timer.State where Element == Void {
    @usableFromInline
    func next() async -> Void? {
        @Dependency(\.clock) var clock
        if fired { return nil }
        if Task.isCancelled { return nil }

        try? await clock.sleep(for: delay)
        if Task.isCancelled { return nil }

        fired = true
        return ()
    }
}
