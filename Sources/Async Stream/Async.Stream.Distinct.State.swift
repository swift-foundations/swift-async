public import Async_Primitives
public import Ownership_Primitives

extension Async.Stream {

    public struct Distinct: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream {

    public var distinct: Distinct { Distinct(base: self) }
}

extension Async.Stream.Distinct {

    @usableFromInline
    actor State {
        @usableFromInline
        let box: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let areEqual: @Sendable (Element, Element) -> Bool

        @usableFromInline
        var previous: Element?

        @usableFromInline
        init(
            stream: Async.Stream<Element>,
            areEqual: @escaping @Sendable (Element, Element) -> Bool
        ) {
            self.box = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.areEqual = areEqual
        }
    }
}

extension Async.Stream.Distinct.State {
    @usableFromInline
    func next() async -> Element? {
        while true {
            guard let element = await box.next() else { return nil }

            if let prev = previous, areEqual(prev, element) {

                continue
            }

            previous = element
            return element
        }
    }
}

extension Async.Stream.Distinct where Element: Equatable {

    public func untilChanged() -> Async.Stream<Element> {
        untilChanged(==)
    }
}

extension Async.Stream.Distinct {

    public func untilChanged(
        _ areEqual: @escaping @Sendable (Element, Element) -> Bool
    ) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Distinct.State(stream: base, areEqual: areEqual)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }

    public func untilChanged<Key: Equatable & Sendable>(
        by key: @escaping @Sendable (Element) -> Key
    ) -> Async.Stream<Element> {
        untilChanged { key($0) == key($1) }
    }
}
