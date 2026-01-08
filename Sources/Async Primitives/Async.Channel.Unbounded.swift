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

import StandardsCollections
import Synchronization

extension Async.Channel {
    /// Unbounded MPMC channel with async receive and cancellation support.
    ///
    /// Provides a multi-producer, multi-consumer channel with unlimited
    /// buffering capacity. Sends are synchronous and never block. Receives
    /// are asynchronous and suspend until an element is available.
    ///
    /// ## Pattern
    /// - Producers call `send(_:)` (synchronous, throws if closed)
    /// - Consumers call `receive()` (async, suspends until element available)
    ///
    /// ## Cancellation Safety
    /// When a task is cancelled while waiting in `receive()`:
    /// - The waiter is immediately removed from the queue (O(n) deque rebuild)
    /// - The operation throws `Error.cancelled`
    /// - Cancelled tasks always make progress (no deadlock)
    ///
    /// ## FIFO Waiter Queue
    /// Multiple tasks may call `receive()` concurrently. Waiters are served
    /// in FIFO order. Cancellation removes the specific waiter by ID,
    /// preserving order for other waiters.
    ///
    /// ## Usage
    /// ```swift
    /// let channel = Async.Channel.Unbounded<Message>()
    ///
    /// // Producer (any thread, sync)
    /// try channel.send(message)
    /// channel.close()
    ///
    /// // Consumer (single task, async)
    /// while let msg = try await channel.receive() {
    ///     process(msg)
    /// }
    /// ```
    ///
    /// ## Thread Safety
    /// All operations are protected by an internal mutex.
    /// Uses `@unchecked Sendable` because internal state is protected
    /// by mutex synchronization.
    public final class Unbounded<Element: Sendable>: @unchecked Sendable {
        internal let _state: Mutex<State>

        /// Creates a new unbounded channel.
        public init() {
            self._state = Mutex(State())
        }
    }
}

// MARK: - Receive

extension Async.Channel.Unbounded {
    /// Receive accessor for grouped operations.
    public var receive: Receive { Receive(channel: self) }

    /// Receive namespace providing receive operations.
    public struct Receive: Sendable {
        let channel: Async.Channel.Unbounded<Element>

        init(channel: Async.Channel.Unbounded<Element>) {
            self.channel = channel
        }

        /// Try to receive an element without suspending.
        ///
        /// - Returns: The next element if available, `nil` if the buffer is empty.
        public func tryOne() -> Element? {
            channel._state.withLock { state -> Element? in
                state.buffer.take.front
            }
        }
    }
}

// MARK: - Lifecycle

extension Async.Channel.Unbounded {
    /// Close the channel, signaling no more elements will be sent.
    ///
    /// After this call:
    /// - Any pending `receive()` returns `nil`
    /// - Future `receive()` calls drain buffer then return `nil`
    /// - Future `send()` calls throw `Error.closed`
    public func close() {
        // All receivers are non-cancelled (cancellation eagerly removes)
        let receivers = _state.withLock { state in
            state.pump(closing: ())
        }

        // Resume all with .finished
        for r in receivers {
            r.continuation.resume(returning: .finished)
        }
    }

    /// Whether the channel has been closed.
    ///
    /// Note: Even when `true`, `receive()` may still return elements
    /// if the buffer is not yet drained.
    public var isClosed: Bool {
        _state.withLock { $0.`is`.closed }
    }
}
