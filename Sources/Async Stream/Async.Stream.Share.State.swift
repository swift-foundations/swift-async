public import Async_Primitives

extension Async.Stream.Share {

    @usableFromInline
    final class State: Sendable {
        @usableFromInline
        let broadcast: Async.Broadcast<Element>

        private let forwardingTask: Task<Void, Never>

        @usableFromInline
        init(upstream: Async.Stream<Element>) {
            let broadcast = Async.Broadcast<Element>()
            self.broadcast = broadcast
            self.forwardingTask = Task {
                for await element in upstream {
                    broadcast.send(element)
                }
                broadcast.finish()
            }
        }

        deinit {
            forwardingTask.cancel()
        }
    }
}
