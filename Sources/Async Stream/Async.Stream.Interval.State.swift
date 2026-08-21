public import Async_Primitives
internal import Clocks_Dependencies

extension Async.Stream.Interval where Element == Int {

    @usableFromInline
    actor State {
        @usableFromInline
        let duration: Duration

        @usableFromInline
        var count: Int = 0

        @usableFromInline
        var started: Bool = false

        @usableFromInline
        init(duration: Duration) {
            self.duration = duration
        }
    }
}

extension Async.Stream.Interval.State {
    @usableFromInline
    func next() async -> Int? {
        @Dependency(\.clock) var clock
        if Task.isCancelled { return nil }

        if started {

            try? await clock.sleep(for: duration)
            if Task.isCancelled { return nil }
        }
        started = true

        defer { count += 1 }
        return count
    }
}
