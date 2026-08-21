public import Async_Primitives
internal import Ownership_Primitives

extension Async {

    public struct Stream<Element: Sendable>: AsyncSequence, Sendable {
        public typealias AsyncIterator = Iterator

        @usableFromInline
        let _makeIterator: @Sendable () -> Iterator

        @inlinable
        public init(_ makeIterator: @escaping @Sendable () -> Iterator) {
            self._makeIterator = makeIterator
        }
    }
}

extension Async.Stream {

    public init<S: AsyncSequence & Sendable>(_ sequence: S) where S.Element == Element {
        self.init {

            let box = Async.Stream<Element>.Iterator.Box(sequence.makeAsyncIterator())
            return Iterator {
                await box.next()
            }
        }
    }
}

extension Async.Stream {
    @inlinable
    public func makeAsyncIterator() -> Iterator {
        _makeIterator()
    }
}

extension Async.Stream {

    public static var empty: Self {
        Self { Iterator { nil } }
    }

    public static var never: Self {
        Self {
            Iterator {

                try? await Task.sleep(for: .seconds(Int64.max))
                return nil
            }
        }
    }

    public static func just(_ value: Element) -> Self {
        from([value])
    }

    public static func from<S: Swift.Sequence & Sendable>(_ sequence: S) -> Self
    where S.Element == Element {
        Self {
            let state = State(Array(sequence))
            return Iterator {
                await state.next()
            }
        }
    }
}
