public import Async_Primitives

extension Async.Stream {

    public struct Prefix: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {

    public var prefix: Prefix { Prefix(base: self) }
}

extension Async.Stream.Prefix {

    public func callAsFunction(_ count: Int) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Prefix.Count(stream: base, count: count)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }

    public func `while`(
        _ predicate: @escaping @Sendable (Element) -> Bool
    ) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Prefix.While(stream: base, predicate: predicate)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }
}
