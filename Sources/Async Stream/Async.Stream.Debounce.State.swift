public import Async_Primitives
internal import Clocks_Dependencies
public import Ownership_Primitives

extension Async.Stream.Debounce {

    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let duration: Duration

        @usableFromInline
        var pending: Element?

        @usableFromInline
        var upstreamDone: Bool = false

        @usableFromInline
        init(stream: Async.Stream<Element>, duration: Duration) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.duration = duration
        }
    }
}

extension Async.Stream.Debounce.State {
    @usableFromInline
    func next() async -> Element? {
        @Dependency(\.clock) var clock
        let resolvedClock = clock
        if upstreamDone {

            if let element = pending {
                pending = nil
                return element
            }
            return nil
        }

        while true {

            let result = await withTaskGroup(of: Async.Stream<Element>.Debounce.Event.self) {
                group in
                group.addTask {
                    if let element = await self.box.next() {
                        return .element(element)
                    } else {
                        return .upstreamComplete
                    }
                }

                if self.pending != nil {
                    group.addTask {

                        try? await resolvedClock.sleep(
                            until: resolvedClock.now.advanced(by: self.duration)
                        )
                        return .timerExpired
                    }
                }

                guard let first = await group.next() else {
                    return Async.Stream<Element>.Debounce.Event.upstreamComplete
                }
                group.cancelAll()
                return first
            }

            switch result {
            case .element(let element):

                pending = element
                continue

            case .timerExpired:

                if let element = pending {
                    pending = nil
                    return element
                }
                continue

            case .upstreamComplete:
                upstreamDone = true

                if let element = pending {
                    pending = nil
                    return element
                }
                return nil
            }
        }
    }
}
