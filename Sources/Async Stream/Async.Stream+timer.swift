public import Async_Primitives

extension Async.Stream {

    public static func timer(after delay: Duration) -> Self where Element == Void {
        Self {
            let state = Async.Stream<Void>.Timer.State(delay: delay)
            return Iterator {
                await state.next()
            }
        }
    }
}

extension Async.Stream {

    public static func timer(after delay: Duration, value: Element) -> Self {
        Self {
            let state = Async.Stream<Element>.Timer.Value.State(delay: delay, value: value)
            return Iterator {
                await state.next()
            }
        }
    }
}
