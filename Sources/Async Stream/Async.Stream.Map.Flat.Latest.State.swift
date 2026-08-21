public import Async_Primitives
internal import Buffer_Primitive
internal import Buffer_Ring_Bounded_Primitive
import Buffer_Ring_Primitive
import Column_Primitives
internal import Memory_Allocator_Primitive
internal import Memory_Heap_Primitives
public import Ownership_Primitives
internal import Standard_Library_Extensions
import Storage_Contiguous_Primitives

extension Async.Stream.Map.Flat {

    public enum Latest {}
}

extension Async.Stream.Map.Flat.Latest {

    @usableFromInline
    actor State<U: Sendable> {
        @usableFromInline
        let outerBox: Async.Stream<Element>.Iterator.Box<Async.Stream<Element>.Iterator>

        @usableFromInline
        let transform: Transform

        @usableFromInline
        var innerTask: Task<Void, Never>?

        @usableFromInline
        var queue: Queue<U> = .init()

        @usableFromInline
        var continuation: CheckedContinuation<U?, Never>?

        @usableFromInline
        var outerDone: Bool = false

        @usableFromInline
        var innerDone: Bool = true

        @usableFromInline
        enum Transform {
            case sync(@Sendable (Element) -> Async.Stream<U>)
            case async(@Sendable (Element) async -> Async.Stream<U>)
        }

        @usableFromInline
        init(stream: Async.Stream<Element>, transform: Transform) {
            self.outerBox = Async.Stream<Element>.Iterator.Box(stream.makeAsyncIterator())
            self.transform = transform
        }
    }
}

extension Async.Stream.Map.Flat.Latest.State {
    @usableFromInline
    func next() async -> U? {
        while true {

            if !queue.isEmpty {
                return queue.dequeue()!
            }

            if innerDone && outerDone {
                return nil
            }

            if innerDone {
                guard let outerElement = await outerBox.next() else {
                    outerDone = true
                    return nil
                }

                innerTask?.cancel()
                innerDone = false

                let innerStream: Async.Stream<U>
                switch transform {
                case .sync(let f): innerStream = f(outerElement)
                case .async(let f): innerStream = await f(outerElement)
                }
                innerTask = Task { [self] in
                    await run { state in
                        for await innerElement in innerStream {
                            await state.receiveInner(innerElement)
                        }
                        await state.markInnerDone()
                    }
                }
            }

            return await withCheckedContinuation { cont in
                self.continuation = cont
            }
        }
    }

    @usableFromInline
    func receiveInner(_ element: sending U) async {
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: element)
        } else {
            queue.enqueue(element)
        }
    }

    @usableFromInline
    func markInnerDone() async {
        innerDone = true
        if let cont = continuation {
            continuation = nil

            cont.resume(returning: nil)
        }
    }
}
