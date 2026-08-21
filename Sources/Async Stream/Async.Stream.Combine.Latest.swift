public import Async_Primitives
internal import Standard_Library_Extensions

extension Async.Stream.Combine {

    public func latest<Other: Sendable>(
        _ other: Async.Stream<Other>
    ) -> Async.Stream<(Element, Other)> {
        Async.Stream<(Element, Other)> { [base] in
            let state = Async.Stream<(Element, Other)>.Combine.State<Element, Other>()

            let task1 = Task {
                await state.run { state in
                    for await element in base {
                        state.updateA(element)
                    }
                    state.completeA()
                }
            }

            let task2 = Task {
                await state.run { state in
                    for await element in other {
                        state.updateB(element)
                    }
                    state.completeB()
                }
            }

            return Async.Stream<(Element, Other)>.Iterator {
                let result = await state.receive()
                if result == nil {
                    task1.cancel()
                    task2.cancel()
                }
                return result
            }
        }
    }
}
