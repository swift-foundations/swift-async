public import Async_Primitives

extension Async.Stream where Element == Int {

    public static func interval(_ duration: Duration) -> Self {
        Self {
            let state = Async.Stream<Int>.Interval.State(duration: duration)
            return Iterator {
                await state.next()
            }
        }
    }
}
