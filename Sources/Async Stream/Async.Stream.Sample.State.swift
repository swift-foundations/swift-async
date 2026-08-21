public import Async_Primitives
public import Ownership_Primitives
internal import Standard_Library_Extensions

extension Async.Stream.Sample {

    @usableFromInline
    actor State<Trigger: Sendable> {
        @usableFromInline
        var latest: Element?

        @usableFromInline
        var sourceTask: Task<Void, Never>?

        @usableFromInline
        var triggerBox: Async.Stream<Element>.Iterator.Box<Async.Stream<Trigger>.Iterator>

        @usableFromInline
        var sourceDone: Bool = false

        @usableFromInline
        var started: Bool = false

        @usableFromInline
        let source: Async.Stream<Element>

        @usableFromInline
        init(source: Async.Stream<Element>, trigger: Async.Stream<Trigger>) {
            self.source = source
            self.triggerBox = Async.Stream<Element>.Iterator.Box(trigger.makeAsyncIterator())
        }
    }
}

extension Async.Stream.Sample.State {
    @usableFromInline
    func startSourceTask() {
        guard !started else { return }
        started = true

        let source = self.source
        sourceTask = Task { [self] in
            await run { state in
                for await element in source {
                    await state.updateLatest(element)
                }
                await state.markSourceDone()
            }
        }
    }

    @usableFromInline
    func updateLatest(_ element: sending Element) async {
        latest = element
    }

    @usableFromInline
    func markSourceDone() async {
        sourceDone = true
    }

    @usableFromInline
    func next() async -> Element? {
        startSourceTask()

        while true {

            guard await triggerBox.next() != nil else {
                sourceTask?.cancel()
                return nil
            }

            if let value = latest {
                return value
            }

            if sourceDone {
                return nil
            }
        }
    }
}
