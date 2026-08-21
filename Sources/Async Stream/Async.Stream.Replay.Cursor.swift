public import Async_Primitives

extension Async.Stream.Replay {

    @usableFromInline
    actor Cursor {
        @usableFromInline
        let state: Async.Stream<Element>.Replay.State

        @usableFromInline
        let connection: Async.Stream<Element>.Replay.Connection

        @usableFromInline
        var subscription: Async.Stream<Element>.Replay.Subscription?

        @usableFromInline
        init(
            state: Async.Stream<Element>.Replay.State,
            connection: Async.Stream<Element>.Replay.Connection
        ) {
            self.state = state
            self.connection = connection
        }

        deinit {
            if let subscription {
                let state = self.state
                Task { await state.unsubscribe(subscription) }
            }
        }
    }
}

extension Async.Stream.Replay.Cursor {
    @usableFromInline
    func next() async -> Element? {
        if subscription == nil {
            subscription = await state.subscribe()
        }
        return await subscription!.next()
    }
}
