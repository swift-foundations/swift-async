public import Async_Primitives
public import Ownership_Primitives

extension Async.Stream.Concat {

    @usableFromInline
    actor State {
        @usableFromInline
        var boxA: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var boxB: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var inFirst: Bool = true

        @usableFromInline
        init(a: Async.Stream<Element>, b: Async.Stream<Element>) {
            self.boxA = Async.Stream<Element>.Iterator.Box(a.makeAsyncIterator())
            self.boxB = Async.Stream<Element>.Iterator.Box(b.makeAsyncIterator())
        }
    }
}

extension Async.Stream.Concat.State {
    @usableFromInline
    func next() async -> Element? {
        if inFirst {
            if let element = await boxA.next() {
                return element
            }
            inFirst = false
        }
        return await boxB.next()
    }
}
