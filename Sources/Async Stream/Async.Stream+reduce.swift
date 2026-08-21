public import Async_Primitives

extension Async.Stream {

    public func reduce<Result: Sendable>(
        _ initial: Result,
        _ accumulator: @escaping @Sendable (Result, Element) -> Result
    ) async -> Result {
        var result = initial
        for await element in self {
            result = accumulator(result, element)
        }
        return result
    }
}
