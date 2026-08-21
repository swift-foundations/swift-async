public import Async_Primitives

extension Async.Stream {

    public func scan<Result: Sendable>(
        _ initial: sending Result,
        _ accumulator: @escaping @Sendable (Result, Element) -> Result
    ) -> Async.Stream<Result> {
        let captured = initial
        return Async.Stream<Result> { [self] in
            let state = Async.Stream<Element>.Scan.State(
                stream: self,
                initial: captured,
                accumulator: accumulator
            )
            return Async.Stream<Result>.Iterator {
                await state.next()
            }
        }
    }
}
