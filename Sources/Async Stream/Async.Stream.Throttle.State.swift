public import Async_Primitives
public import Clock_Primitives
internal import Clocks_Dependencies
public import Ownership_Primitives

extension Async.Stream.Throttle {

    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let duration: Duration

        @usableFromInline
        var lastEmitTime: Clock.`Any`<Duration>.Instant?

        @usableFromInline
        init(stream: Async.Stream<Element>, duration: Duration) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.duration = duration
        }
    }
}

extension Async.Stream.Throttle.State {
    @usableFromInline
    func next() async -> Element? {
        @Dependency(\.clock) var clock
        while true {
            guard let element = await box.next() else { return nil }

            let now = clock.now

            if let lastTime = lastEmitTime {
                let elapsed = lastTime.duration(to: now)
                if elapsed < duration {

                    continue
                }
            }

            lastEmitTime = now
            return element
        }
    }
}
