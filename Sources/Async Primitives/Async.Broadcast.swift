// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-runtime open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-runtime project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import StandardsCollections
import Synchronization

extension Async {
    /// Multi-reader broadcast channel.
    ///
    /// Provides a single-producer, multi-consumer channel where each subscriber
    /// receives all messages sent after their subscription. Messages are delivered
    /// in order to all subscribers.
    ///
    /// ## Pattern
    /// - Single producer calls `send(_:)` (synchronous, never blocks)
    /// - Multiple consumers call `subscribe()` to get a subscription
    /// - Each subscription receives all messages sent after subscription
    ///
    /// ## Usage
    /// ```swift
    /// let broadcast = Async.Broadcast<Message>()
    ///
    /// // Create subscriptions before sending
    /// let sub1 = broadcast.subscribe()
    /// let sub2 = broadcast.subscribe()
    ///
    /// // Producer
    /// broadcast.send(message)
    /// broadcast.finish()
    ///
    /// // Consumers (independent tasks)
    /// for await msg in sub1 {
    ///     process(msg)
    /// }
    /// ```
    ///
    /// ## Thread Safety
    /// All operations are protected by an internal mutex.
    /// Uses `@unchecked Sendable` because internal state is protected
    /// by mutex synchronization.
    public final class Broadcast<Element: Sendable>: @unchecked Sendable {
        private let _state: Mutex<State>
        private let bufferCapacity: Int

        /// Creates a new broadcast channel.
        ///
        /// - Parameter bufferCapacity: Maximum number of elements to buffer for late subscribers.
        ///   Elements are discarded when the buffer is full and all subscribers have consumed them.
        public init(bufferCapacity: Int = 64) {
            precondition(bufferCapacity > 0, "Broadcast buffer capacity must be greater than zero")
            self.bufferCapacity = bufferCapacity
            self._state = Mutex(State())
        }
    }
}

// MARK: - State

extension Async.Broadcast {
    struct State {
        var buffer: Deque<(index: UInt64, element: Element)> = .init()
        var nextIndex: UInt64 = 0
        var subscribers: Dictionary<UInt64, SubscriberState>.Ordered = .init()
        var cursorHeap: Heap<UInt64> = .init()  // Lazy-cleaned min-heap of subscriber cursors
        var nextSubscriberID: UInt64 = 0
        var isFinished: Bool = false

        /// Get the minimum cursor, cleaning stale values from heap.
        ///
        /// Cursors only increase and subscribers can be removed, so heap may contain
        /// stale values. This method lazily cleans them during lookup.
        mutating func minCursor() -> UInt64? {
            while let min = cursorHeap.peek.min {
                if subscribers.values.contains(where: { $0.cursor == min }) {
                    return min
                }
                _ = cursorHeap.take.min
            }
            return nil
        }
    }

    struct SubscriberState {
        var cursor: UInt64
        var continuation: CheckedContinuation<Element?, Never>?
    }
}

// MARK: - Send

extension Async.Broadcast {
    /// Send an element to all subscribers.
    ///
    /// If a subscriber is awaiting, delivers immediately.
    /// Otherwise, buffers the element for later consumption.
    ///
    /// After `finish()`, sends are silently ignored.
    ///
    /// - Parameter element: The element to broadcast.
    public func send(_ element: Element) {
        let continuationsToResume: [(CheckedContinuation<Element?, Never>, Element)] = _state.withLock { state in
            guard !state.isFinished else { return [] }

            let index = state.nextIndex
            state.nextIndex += 1

            // Add to buffer
            state.buffer.push.back((index, element))

            // Trim buffer if needed (keep elements that some subscriber hasn't seen yet)
            let minCursor = state.minCursor() ?? index
            while state.buffer.count > bufferCapacity {
                if let front = state.buffer.peek.front, front.index < minCursor {
                    _ = state.buffer.take.front
                } else {
                    break
                }
            }

            // Find and wake up waiting subscribers
            var toResume: [(CheckedContinuation<Element?, Never>, Element)] = []
            for (id, var subscriber) in state.subscribers {
                if subscriber.cursor == index, let cont = subscriber.continuation {
                    subscriber.cursor = index + 1
                    state.cursorHeap.push(subscriber.cursor)  // Track new cursor position
                    subscriber.continuation = nil
                    state.subscribers[id] = subscriber
                    toResume.append((cont, element))
                }
            }
            return toResume
        }

        for (continuation, element) in continuationsToResume {
            continuation.resume(returning: element)
        }
    }

    /// Signal that no more elements will be sent.
    ///
    /// After this call:
    /// - All pending receives return remaining buffered elements, then `nil`
    /// - Future `send()` calls are silently ignored
    public func finish() {
        let continuationsToResume: [CheckedContinuation<Element?, Never>] = _state.withLock { state in
            state.isFinished = true

            // Wake up all waiting subscribers with nil if they've consumed everything
            var toResume: [CheckedContinuation<Element?, Never>] = []
            for (id, var subscriber) in state.subscribers {
                if let cont = subscriber.continuation {
                    // Check if there are buffered elements for this subscriber
                    let hasBufferedElement = state.buffer.contains { $0.index >= subscriber.cursor }
                    if !hasBufferedElement {
                        subscriber.continuation = nil
                        state.subscribers[id] = subscriber
                        toResume.append(cont)
                    }
                }
            }
            return toResume
        }

        for continuation in continuationsToResume {
            continuation.resume(returning: nil)
        }
    }

    /// Whether `finish()` has been called.
    public var isFinished: Bool {
        _state.withLock { $0.isFinished }
    }
}

// MARK: - Subscribe

extension Async.Broadcast {
    /// Create a new subscription starting from the current position.
    ///
    /// The subscription will receive all elements sent after this call.
    ///
    /// - Returns: A subscription that can be iterated asynchronously.
    public func subscribe() -> Subscription {
        let (id, cursor) = _state.withLock { state -> (UInt64, UInt64) in
            let id = state.nextSubscriberID
            state.nextSubscriberID += 1
            let cursor = state.nextIndex
            state.subscribers[id] = SubscriberState(cursor: cursor, continuation: nil)
            state.cursorHeap.push(cursor)  // Track initial cursor position
            return (id, cursor)
        }
        return Subscription(broadcast: self, id: id, cursor: cursor)
    }

    /// A subscription to a broadcast channel.
    ///
    /// Conforms to `AsyncSequence` for use in `for await` loops.
    public struct Subscription: Sendable, AsyncSequence {
        let broadcast: Async.Broadcast<Element>
        let id: UInt64
        var cursor: UInt64

        init(broadcast: Async.Broadcast<Element>, id: UInt64, cursor: UInt64) {
            self.broadcast = broadcast
            self.id = id
            self.cursor = cursor
        }

        public func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(broadcast: broadcast, id: id)
        }

        /// Unsubscribe and release resources.
        public func cancel() {
            let continuationToCancel: CheckedContinuation<Element?, Never>? = broadcast._state.withLock { state -> CheckedContinuation<Element?, Never>? in
                guard let subscriber = state.subscribers.values.remove(id) else { return nil }
                return subscriber.continuation
            }
            continuationToCancel?.resume(returning: nil)
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            let broadcast: Async.Broadcast<Element>
            let id: UInt64

            public mutating func next() async -> Element? {
                await withCheckedContinuation { continuation in
                    let immediateResult: Element?? = broadcast._state.withLock { state in
                        guard var subscriber = state.subscribers[id] else {
                            // Unsubscribed
                            return Optional<Element?>.some(nil)
                        }

                        // Check for buffered element
                        if let entry = state.buffer.first(where: { $0.index >= subscriber.cursor }) {
                            if entry.index == subscriber.cursor {
                                subscriber.cursor += 1
                                state.cursorHeap.push(subscriber.cursor)  // Track new cursor position
                                state.subscribers[id] = subscriber
                                return Optional<Element?>.some(entry.element)
                            }
                        }

                        // Check if finished and no more elements
                        if state.isFinished {
                            return Optional<Element?>.some(nil)
                        }

                        // Need to wait
                        subscriber.continuation = continuation
                        state.subscribers[id] = subscriber
                        return nil
                    }

                    if let result = immediateResult {
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }
}
