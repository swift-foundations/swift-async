public import Async_Primitives
public import Ownership_Primitives

extension Async.Stream.Prefix {

    @usableFromInline
    actor Count {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var remaining: Int

        @usableFromInline
        init(stream: Async.Stream<Element>, count: Int) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.remaining = count
        }
    }
}

extension Async.Stream.Prefix.Count {
    @usableFromInline
    func next() async -> Element? {
        if remaining <= 0 { return nil }
        guard let element = await box.next() else { return nil }
        remaining -= 1
        return element
    }
}
