public import Async_Primitives

extension Async.Stream.Map {

    public struct Flat: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }

    public var flat: Flat { Flat(base: base) }
}

extension Async.Stream.Map.Flat {

    public func callAsFunction<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let state = Async.Stream<Element>.Map.Flat.State<U>(
                stream: base,
                transform: .sync(transform)
            )
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }

    public func callAsFunction<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let state = Async.Stream<Element>.Map.Flat.State<U>(
                stream: base,
                transform: .async(transform)
            )
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }
}
