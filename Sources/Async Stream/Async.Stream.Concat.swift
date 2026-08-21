public import Async_Primitives

extension Async.Stream {

    public struct Concat: Sendable {}
}

extension Async.Stream {

    public static var concat: Concat { Concat() }
}

extension Async.Stream.Concat {

    public func callAsFunction(
        _ a: Async.Stream<Element>,
        _ b: Async.Stream<Element>
    ) -> Async.Stream<Element> {
        Async.Stream<Element> {
            let state = Async.Stream<Element>.Concat.State(a: a, b: b)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }

    public func callAsFunction(
        _ a: Async.Stream<Element>,
        _ b: Async.Stream<Element>,
        _ c: Async.Stream<Element>
    ) -> Async.Stream<Element> {
        self(self(a, b), c)
    }

    public func callAsFunction(
        _ streams: [Async.Stream<Element>]
    ) -> Async.Stream<Element> {
        guard !streams.isEmpty else { return .empty }
        return streams.dropFirst().reduce(streams[0]) { self($0, $1) }
    }
}
