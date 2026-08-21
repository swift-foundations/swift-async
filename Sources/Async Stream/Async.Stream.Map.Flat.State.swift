public import Async_Primitives
public import Ownership_Primitives

extension Async.Stream.Map.Flat {

    @usableFromInline
    actor State<U: Sendable> {
        @usableFromInline
        let outerBox: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let transform: Transform

        @usableFromInline
        var innerBox: Async.Stream<Element>.Iterator.Box<Async.Stream<U>.Iterator>?

        @usableFromInline
        enum Transform {
            case sync(@Sendable (Element) -> Async.Stream<U>)
            case async(@Sendable (Element) async -> Async.Stream<U>)
        }

        @usableFromInline
        init(stream: Async.Stream<Element>, transform: Transform) {
            self.outerBox = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.transform = transform
        }
    }
}

extension Async.Stream.Map.Flat.State {
    @usableFromInline
    func next() async -> U? {
        while true {

            if let inner = innerBox, let element = await inner.next() {
                return element
            }

            guard let outerElement = await outerBox.next() else {
                return nil
            }

            let innerStream: Async.Stream<U>
            switch transform {
            case .sync(let f): innerStream = f(outerElement)
            case .async(let f): innerStream = await f(outerElement)
            }
            innerBox = Async.Stream<Element>.Iterator.Box(innerStream.makeAsyncIterator())
        }
    }
}
