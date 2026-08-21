public import Async_Primitives
internal import Standard_Library_Extensions

extension Async.Stream {

    public enum Replay {}
}

extension Async.Stream {

    public func replay(bufferSize: Int) -> Self {
        replayForTesting(bufferSize: bufferSize).stream
    }

    package func replayForTesting(
        bufferSize: Int
    ) -> (stream: Self, subscriptionCount: @Sendable () async -> Int) {
        let state = Async.Stream<Element>.Replay.State(bufferSize: bufferSize)

        let forwardingTask = Task { [self] in
            await state.run { state in
                for await element in self {

                    await state.send(element)
                }
                await state.finish()
            }
        }
        let connection = Async.Stream<Element>.Replay.Connection(forwardingTask)

        let stream = Self {

            let wrapper = Async.Stream<Element>.Replay.Cursor(state: state, connection: connection)
            return Iterator {
                await wrapper.next()
            }
        }
        return (stream, { await state.subscriptionCount })
    }
}
