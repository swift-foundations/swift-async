public import Async_Primitives

extension Async.Stream {

    public static func repeating(_ value: Element, count: Int? = nil) -> Self {
        Self {
            let state = Async.Stream<Element>.Repeat.State(value: value, count: count)
            return Iterator {
                await state.next()
            }
        }
    }
}

extension Async.Stream {

    public static func repeating(
        _ value: Element,
        every interval: Duration,
        count: Int? = nil
    ) -> Self {
        Self {
            let state = Async.Stream<Element>.Repeat.Interval.State(
                value: value,
                interval: interval,
                count: count
            )
            return Iterator {
                await state.next()
            }
        }
    }
}
