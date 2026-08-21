public import Async_Primitives
internal import Ownership_Primitives

extension Async.Stream {

    public init(from broadcast: Async.Broadcast<Element>) {
        self.init {
            let subscription = broadcast.subscribe()
            let box = Async.Stream<Element>.Iterator.Box(subscription.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }

    public init(from subscription: Async.Broadcast<Element>.Subscription) {
        self.init {
            let box = Async.Stream<Element>.Iterator.Box(subscription.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}

extension Async.Stream {

    public init(from receiver: consuming Async.Channel<Element>.Unbounded.Receiver) {

        let elements = receiver.elements
        self.init {
            let box = Async.Stream<Element>.Iterator.Box(elements.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}

extension Async.Stream {

    public init(from receiver: consuming Async.Channel<Element>.Bounded.Receiver) {
        let elements = receiver.elements
        self.init {
            let box = Async.Stream<Element>.Iterator.Box(elements.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}

extension Async.Stream {

    @discardableResult
    public func forward(to sender: Async.Channel<Element>.Unbounded.Sender) -> Task<Void, Never> {
        Task {
            forwarding: for await element in self {
                do throws(Async.Channel<Element>.Error) {
                    try sender.send(element)
                } catch {
                    break forwarding
                }
            }
            sender.close()
        }
    }

    @discardableResult
    public func forward(to sender: Async.Channel<Element>.Bounded.Sender) -> Task<Void, Never> {
        Task {
            forwarding: for await element in self {
                do throws(Async.Channel<Element>.Error) {
                    try await sender.send(element)
                } catch {
                    break forwarding
                }
            }
            sender.close()
        }
    }

    @discardableResult
    public func forward(to broadcast: Async.Broadcast<Element>) -> Task<Void, Never> {
        Task {
            for await element in self {
                broadcast.send(element)
            }
            broadcast.finish()
        }
    }
}

extension Async.Broadcast {

    public var stream: Async.Stream<Element> {
        Async.Stream(from: self)
    }
}

extension Async.Channel.Unbounded.Receiver where Element: Sendable {

    public consuming func stream() -> Async.Stream<Element> {
        Async.Stream(from: consume self)
    }
}

extension Async.Channel.Bounded.Receiver where Element: Sendable {

    public consuming func stream() -> Async.Stream<Element> {
        Async.Stream(from: consume self)
    }
}
