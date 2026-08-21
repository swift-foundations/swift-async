public import Async_Primitives

extension Async.Stream.Latest {

    public func from<Other: Sendable>(
        _ other: Async.Stream<Other>
    ) -> Async.Stream<(Element, Other)> {
        Async.Stream<(Element, Other)> { [base] in
            let state = Async.Stream<Element>.Latest.State<Other>(source: base, other: other)
            return Async.Stream<(Element, Other)>.Iterator {
                await state.next()
            }
        }
    }

    public func from<Other: Sendable, Result: Sendable>(
        _ other: Async.Stream<Other>,
        _ transform: @escaping @Sendable (Element, Other) -> Result
    ) -> Async.Stream<Result> {
        self.from(other).map { transform($0.0, $0.1) }
    }
}
