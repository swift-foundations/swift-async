// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Async_Primitives
public import Ownership_Primitives
internal import Standard_Library_Extensions

extension Async.Stream.Map.Flat {
    /// Namespace for latest operations.
    public enum Latest {}
}

extension Async.Stream.Map.Flat.Latest {
    /// Internal state for flat map latest.
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
            // Return buffered inner value if available
            if !queue.isEmpty {
                return queue.dequeue()!
            }

            // If inner is done and outer is done, we're complete
            if innerDone && outerDone {
                return nil
            }

            // Try to get next outer element
            if innerDone {
                guard let outerElement = await outerBox.next() else {
                    outerDone = true
                    return nil
                }

                // Cancel any existing inner task
                innerTask?.cancel()
                innerDone = false

                // Start new inner stream
                let innerStream: Async.Stream<U>
                switch transform {
                case .sync(let f): innerStream = f(outerElement)
                case .async(let f): innerStream = await f(outerElement)
                }
                innerTask = Task { [self] in
                    await self.run { state in
                        for await innerElement in innerStream {
                            await state.receiveInner(innerElement)
                        }
                        await state.markInnerDone()
                    }
                }
            }

            // Wait for inner value or completion
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
            // Resume to re-check state
            cont.resume(returning: nil)
        }
    }
}
