public import Async_Primitives

extension Async.Stream {

    public enum Share {}
}

extension Async.Stream {

    public func share() -> Self {

        let state = Async.Stream<Element>.Share.State(upstream: self)

        return Self {
            let cursor = Async.Stream<Element>.Share.Cursor(state: state)
            return Iterator {
                await cursor.next()
            }
        }
    }
}
