public import Async_Primitives
internal import Ownership_Primitives

extension Async.Stream {

    public struct Map: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {

    public var map: Map { Map(base: self) }
}

extension Async.Stream.Map {

    public func callAsFunction<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> U
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let box = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                guard let element = await box.next() else { return nil }
                return transform(element)
            }
        }
    }

    public func callAsFunction<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> U
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let box = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                guard let element = await box.next() else { return nil }
                return await transform(element)
            }
        }
    }
}

extension Async.Stream.Map {

    public func compact<U: Sendable>(
        _ transform: @escaping @Sendable (Element) -> U?
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let box = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                while true {
                    guard let element = await box.next() else { return nil }
                    if let transformed = transform(element) {
                        return transformed
                    }
                }
            }
        }
    }

    public func compact<U: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> U?
    ) -> Async.Stream<U> {
        Async.Stream<U> { [base] in
            let box = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            return Async.Stream<U>.Iterator {
                while true {
                    guard let element = await box.next() else { return nil }
                    if let transformed = await transform(element) {
                        return transformed
                    }
                }
            }
        }
    }
}
