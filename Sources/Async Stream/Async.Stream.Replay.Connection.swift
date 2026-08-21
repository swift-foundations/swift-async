extension Async.Stream.Replay {

    @usableFromInline
    final class Connection: Sendable {
        @usableFromInline
        let task: Task<Void, Never>

        @usableFromInline
        init(_ task: Task<Void, Never>) {
            self.task = task
        }

        deinit {
            task.cancel()
        }
    }
}
