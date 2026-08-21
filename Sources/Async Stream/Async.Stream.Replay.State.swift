public import Async_Primitives
internal import Buffer_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Primitive
internal import Buffer_Ring_Primitives
internal import Cardinal_Primitives
public import Column_Primitives
internal import Memory_Allocator_Primitive
internal import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives

extension Async.Stream.Replay {

    @usableFromInline
    actor State {
        @usableFromInline
        var ring: Column.Ring<Element>.Bounded

        @usableFromInline
        var subscriptions: [Async.Stream<Element>.Replay.Subscription] = []

        @usableFromInline
        var finished: Bool = false

        @usableFromInline
        init(bufferSize: Int) {

            let capacity = try! Index<Element>.Count(max(1, bufferSize))
            self.ring = Column.Ring<Element>.Bounded(minimumCapacity: capacity)
        }
    }
}

extension Async.Stream.Replay.State {

    @usableFromInline
    func send(_ element: sending Element) async {

        if ring.isFull {
            _ = ring.pop.front()
        }
        ring.push.back(element)

        for subscription in subscriptions {
            await subscription.receive(element)
        }
    }

    @usableFromInline
    func finish() async {
        finished = true
        for subscription in subscriptions {
            await subscription.finish()
        }
    }

    @usableFromInline
    func subscribe() -> Async.Stream<Element>.Replay.Subscription {
        var replay: [Element] = []
        ring.forEach { replay.append($0) }
        let subscription = Async.Stream<Element>.Replay.Subscription(
            replay: replay,
            finished: finished
        )
        if !finished {
            subscriptions.append(subscription)
        }
        return subscription
    }

    @usableFromInline
    func unsubscribe(_ subscription: Async.Stream<Element>.Replay.Subscription) {
        subscriptions.removeAll { $0 === subscription }
    }

    @usableFromInline
    var subscriptionCount: Int {
        subscriptions.count
    }
}
