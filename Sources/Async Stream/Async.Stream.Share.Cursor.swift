public import Async_Primitives

extension Async.Stream.Share {

    @usableFromInline
    actor Cursor {
        @usableFromInline
        let subscription: Async.Broadcast<Element>.Subscription

        @usableFromInline
        var iterator: Async.Broadcast<Element>.Subscription.AsyncIterator

        @usableFromInline
        let keepAlive: Async.Stream<Element>.Share.State

        @usableFromInline
        init(state: Async.Stream<Element>.Share.State) {
            let subscription = state.broadcast.subscribe()
            self.subscription = subscription
            self.iterator = subscription.makeAsyncIterator()
            self.keepAlive = state
        }

        deinit {
            subscription.cancel()
        }
    }
}

extension Async.Stream.Share.Cursor {
    @usableFromInline
    func next() async -> Element? {

        var localIterator = iterator
        let result: Element?
        do throws(Async.Broadcast<Element>.Error) {
            result = try await localIterator.next()
        } catch {
            result = nil
        }
        iterator = localIterator
        return result
    }
}
