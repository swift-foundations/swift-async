public import Async_Primitives

extension Async.Stream.Repeat {

    @usableFromInline
    actor State {
        @usableFromInline
        let value: Element

        @usableFromInline
        var remaining: Int?

        @usableFromInline
        init(value: sending Element, count: Int?) {
            self.value = value
            self.remaining = count
        }
    }
}

extension Async.Stream.Repeat.State {
    @usableFromInline
    func next() async -> Element? {
        if Task.isCancelled { return nil }
        if let r = remaining {
            if r <= 0 { return nil }
            remaining = r - 1
        }
        return value
    }
}
