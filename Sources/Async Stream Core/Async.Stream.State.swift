public import Async_Primitives

extension Async.Stream {

    @usableFromInline
    actor State {
        @usableFromInline
        var elements: [Element]

        @usableFromInline
        var index: Int = 0

        @usableFromInline
        init(_ elements: [Element]) {
            self.elements = elements
        }
    }
}

extension Async.Stream.State {
    @usableFromInline
    func next() -> Element? {
        guard index < elements.count else { return nil }
        defer { index += 1 }
        return elements[index]
    }
}
