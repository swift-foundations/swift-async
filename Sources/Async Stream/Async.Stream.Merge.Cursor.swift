extension Async.Stream.Merge {

    @usableFromInline
    actor Cursor {
        @usableFromInline
        let state: Async.Stream<Element>.Merge.State

        @usableFromInline
        let task1: Task<Void, Never>

        @usableFromInline
        let task2: Task<Void, Never>

        @usableFromInline
        init(
            state: Async.Stream<Element>.Merge.State,
            task1: Task<Void, Never>,
            task2: Task<Void, Never>
        ) {
            self.state = state
            self.task1 = task1
            self.task2 = task2
        }

        deinit {
            task1.cancel()
            task2.cancel()
        }
    }
}

extension Async.Stream.Merge.Cursor {
    @usableFromInline
    func next() async -> Element? {
        let result = await state.receive()
        if result == nil {
            task1.cancel()
            task2.cancel()
        }
        return result
    }
}
