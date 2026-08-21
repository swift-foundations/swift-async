public import Async_Primitives

extension Async.Stream.Map.Flat {

    public func latest<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let state = Async.Stream<Element>.Map.Flat.Latest.State<U>(
                stream: base,
                transform: .sync(transform)
            )
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }

    public func latest<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> Async.Stream<U>
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let state = Async.Stream<Element>.Map.Flat.Latest.State<U>(
                stream: base,
                transform: .async(transform)
            )
            return Async.Stream<U>.Iterator {
                await state.next()
            }
        }
    }
}
