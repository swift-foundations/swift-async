public import Async_Primitives

extension Async.Stream {

    public struct Drop: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {

    public var drop: Drop { Drop(base: self) }
}

extension Async.Stream.Drop {

    public func callAsFunction(_ count: Int) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Drop.Count(stream: base, count: count)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }

    public func `while`(
        _ predicate: @escaping @Sendable (Element) -> Bool
    ) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Drop.While(stream: base, predicate: predicate)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }
}
