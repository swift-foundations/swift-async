public import Async_Primitives
internal import Standard_Library_Extensions

extension Async.Stream {

    public struct Merge: Sendable {}
}

extension Async.Stream {

    public static var merge: Merge { Merge() }
}

extension Async.Stream.Merge {

    public func callAsFunction(
        _ a: Async.Stream<Element>,
        _ b: Async.Stream<Element>
    ) -> Async.Stream<Element> {
        Async.Stream<Element> {
            let state = Async.Stream<Element>.Merge.State()

            let task1 = Task {
                await state.run { state in
                    for await element in a {
                        state.send(element)
                    }
                    state.complete()
                }
            }

            let task2 = Task {
                await state.run { state in
                    for await element in b {
                        state.send(element)
                    }
                    state.complete()
                }
            }

            let cursor = Async.Stream<Element>.Merge.Cursor(
                state: state,
                task1: task1,
                task2: task2
            )

            return Async.Stream<Element>.Iterator {
                await cursor.next()
            }
        }
    }

    public func callAsFunction(
        _ a: Async.Stream<Element>,
        _ b: Async.Stream<Element>,
        _ c: Async.Stream<Element>
    ) -> Async.Stream<Element> {
        self(self(a, b), c)
    }

    public func callAsFunction(
        _ streams: [Async.Stream<Element>]
    ) -> Async.Stream<Element> {
        guard !streams.isEmpty else { return .empty }
        return streams.dropFirst().reduce(streams[0]) { self($0, $1) }
    }
}
