public import Async_Primitives
public import Ownership_Primitives

extension Async.Stream.Drop {

    @usableFromInline
    actor While {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let predicate: @Sendable (Element) -> Bool

        @usableFromInline
        var dropping: Bool = true

        @usableFromInline
        init(stream: Async.Stream<Element>, predicate: @escaping @Sendable (Element) -> Bool) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.predicate = predicate
        }
    }
}

extension Async.Stream.Drop.While {
    @usableFromInline
    func next() async -> Element? {
        while dropping {
            guard let element = await box.next() else { return nil }
            if !predicate(element) {
                dropping = false
                return element
            }
        }
        return await box.next()
    }
}
