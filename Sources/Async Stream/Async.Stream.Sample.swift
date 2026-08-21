public import Async_Primitives

extension Async.Stream {

    public var sample: Sample { Sample(base: self) }

    public struct Sample: Sendable {
        @usableFromInline
        let base: Async.Stream<Element>

        @usableFromInline
        init(base: Async.Stream<Element>) {
            self.base = base
        }
    }
}

extension Async.Stream.Sample {

    public func on<Trigger: Sendable>(
        _ trigger: Async.Stream<Trigger>
    ) -> Async.Stream<Element> {
        Async.Stream<Element> { [base] in
            let state = Async.Stream<Element>.Sample.State<Trigger>(source: base, trigger: trigger)
            return Async.Stream<Element>.Iterator {
                await state.next()
            }
        }
    }
}
