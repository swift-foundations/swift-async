public import Async_Primitives

extension Async.Stream {

    public struct Buffer: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {

    public var buffer: Buffer { Buffer(base: self) }
}

extension Async.Stream.Buffer {

    public func count(_ count: Int) -> Async.Stream<[Element]> {
        Async.Stream<[Element]> { [base] in
            let state = Async.Stream<Element>.Buffer.Count.State(stream: base, count: count)
            return Async.Stream<[Element]>.Iterator {
                await state.next()
            }
        }
    }
}

extension Async.Stream.Buffer {

    public func time(_ duration: Duration) -> Async.Stream<[Element]> {
        Async.Stream<[Element]> { [base] in
            let state = Async.Stream<Element>.Buffer.Time.State(stream: base, duration: duration)
            return Async.Stream<[Element]>.Iterator {
                await state.next()
            }
        }
    }
}

extension Async.Stream.Buffer {

    public func window(count: Int, time duration: Duration) -> Async.Stream<[Element]> {
        Async.Stream<[Element]> { [base] in
            let state = Async.Stream<Element>.Buffer.Window.State(
                stream: base,
                count: count,
                duration: duration
            )
            return Async.Stream<[Element]>.Iterator {
                await state.next()
            }
        }
    }
}
