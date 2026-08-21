public import Async_Primitives
internal import Ownership_Primitives

extension Async.Stream {

    public struct Zip: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {

    public var zip: Zip { Zip(base: self) }
}

extension Async.Stream.Zip {

    public func callAsFunction<Other: Sendable>(
        _ other: Async.Stream<Other>
    ) -> Async.Stream<(Element, Other)> {
        Async.Stream<(Element, Other)> { [base] in
            let boxA = Async.Stream<Element>.Iterator.Box(base.makeAsyncIterator())
            let boxB = Async.Stream<Element>.Iterator.Box(other.makeAsyncIterator())

            return Async.Stream<(Element, Other)>.Iterator {
                async let a = boxA.next()
                async let b = boxB.next()

                guard let elementA = await a, let elementB = await b else {
                    return nil
                }

                return (elementA, elementB)
            }
        }
    }

    public func callAsFunction<Other: Sendable, Result: Sendable>(
        _ other: Async.Stream<Other>,
        _ transform: @escaping @Sendable (Element, Other) -> Result
    ) -> Async.Stream<Result> {
        self(other).map { transform($0.0, $0.1) }
    }
}
