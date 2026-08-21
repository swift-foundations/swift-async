extension Async {

    public struct Filter<Base: AsyncSequence>: AsyncSequence {
        public typealias Element = Base.Element

        @usableFromInline
        let base: Base

        @usableFromInline
        let predicate: Predicate

        @usableFromInline
        enum Predicate {
            case sync((Base.Element) -> Bool)
            case async((Base.Element) async -> Bool)
        }

        @usableFromInline
        init(base: Base, predicate: Predicate) {
            self.base = base
            self.predicate = predicate
        }

        public struct Iterator: AsyncIteratorProtocol {
            @usableFromInline
            var baseIterator: Base.AsyncIterator

            @usableFromInline
            let predicate: Predicate

            @usableFromInline
            init(
                baseIterator: Base.AsyncIterator,
                predicate: Predicate
            ) {
                self.baseIterator = baseIterator
                self.predicate = predicate
            }

            @inlinable
            public mutating func next(

                isolation actor: isolated (any Actor)? = #isolation
            ) async -> Base.Element? {
                while true {
                    let element: Base.Element?
                    do throws(Base.Failure) {
                        element = try await baseIterator.next(isolation: actor)
                    } catch {
                        return nil
                    }
                    guard let element else { return nil }
                    let included: Bool
                    switch predicate {
                    case .sync(let f): included = f(element)
                    case .async(let f): included = await f(element)
                    }
                    if included {
                        return element
                    }
                }
            }
        }

    }
}

extension Async.Filter {
    @inlinable
    public func makeAsyncIterator() -> Iterator {
        Iterator(baseIterator: base.makeAsyncIterator(), predicate: predicate)
    }
}
