public import Async_Primitives

extension Async.Stream {

    public struct Latest: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {

    public var latest: Latest { Latest(base: self) }
}
