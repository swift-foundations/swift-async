public import Async_Primitives
internal import Clocks_Dependencies

extension Async.Stream.Timer.Value {

    @usableFromInline
    actor State {
        @usableFromInline
        let delay: Duration

        @usableFromInline
        let value: Element

        @usableFromInline
        var fired: Bool = false

        @usableFromInline
        init(delay: Duration, value: sending Element) {
            self.delay = delay
            self.value = value
        }
    }
}

extension Async.Stream.Timer.Value.State {
    @usableFromInline
    func next() async -> Element? {
        @Dependency(\.clock) var clock
        if fired { return nil }
        if Task.isCancelled { return nil }

        try? await clock.sleep(for: delay)
        if Task.isCancelled { return nil }

        fired = true
        return value
    }
}
