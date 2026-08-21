public import Async_Primitives
internal import Ownership_Primitives

extension Async.Stream {

    public func multicast(to broadcast: Async.Broadcast<Element>) -> Connectable {
        Connectable(upstream: self, broadcast: broadcast)
    }

    public struct Connectable: Sendable {
        @usableFromInline
        let upstream: Async.Stream<Element>

        @usableFromInline
        let broadcast: Async.Broadcast<Element>

        @usableFromInline
        init(upstream: Async.Stream<Element>, broadcast: Async.Broadcast<Element>) {
            self.upstream = upstream
            self.broadcast = broadcast
        }
    }
}

extension Async.Stream.Connectable {

    @discardableResult
    public func connect() -> Task<Void, Never> {
        Task {
            for await element in upstream {
                broadcast.send(element)
            }
            broadcast.finish()
        }
    }

    public var stream: Async.Stream<Element> {
        Async.Stream<Element> {
            let subscription = broadcast.subscribe()
            let box = Async.Stream<Element>.Iterator.Box(subscription.makeAsyncIterator())
            return Async.Stream<Element>.Iterator {
                await box.next()
            }
        }
    }
}
