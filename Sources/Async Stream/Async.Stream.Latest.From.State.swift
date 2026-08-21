public import Async_Primitives
public import Ownership_Primitives
internal import Standard_Library_Extensions

extension Async.Stream.Latest {

    @usableFromInline
    actor State<Other: Sendable> {
        @usableFromInline
        var latestOther: Other?

        @usableFromInline
        var sourceBox: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        var otherTask: Task<Void, Never>?

        @usableFromInline
        var started: Bool = false

        @usableFromInline
        let other: Async.Stream<Other>

        @usableFromInline
        init(source: Async.Stream<Element>, other: Async.Stream<Other>) {
            self.sourceBox = Async.Stream<Element>.Iterator.Box(source.makeAsyncIterator())
            self.other = other
        }
    }
}

extension Async.Stream.Latest.State {
    @usableFromInline
    func startOtherTask() {
        guard !started else { return }
        started = true

        let other = self.other
        otherTask = Task { [self] in
            await run { state in
                for await element in other {
                    await state.updateLatestOther(element)
                }
            }
        }
    }

    @usableFromInline
    func updateLatestOther(_ element: sending Other) async {
        latestOther = element
    }

    @usableFromInline
    func next() async -> (Element, Other)? {
        startOtherTask()

        while true {
            guard let element = await sourceBox.next() else {
                otherTask?.cancel()
                return nil
            }

            if let other = latestOther {
                return (element, other)
            }

        }
    }
}
