public import Async_Primitives
public import Ownership_Primitives

extension Async.Stream.Last {

    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var lastElement: Element?

        @usableFromInline
        var done: Bool = false

        @usableFromInline
        init(stream: Async.Stream<Element>) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
        }
    }
}

extension Async.Stream.Last.State {
    @usableFromInline
    func next() async -> Element? {
        if done { return nil }

        while let element = await box.next() {
            lastElement = element
        }

        done = true
        return lastElement
    }
}
