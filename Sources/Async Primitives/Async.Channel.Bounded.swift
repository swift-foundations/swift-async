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

extension Async.Channel {
    /// Bounded channel with backpressure.
    ///
    /// Provides a capacity-limited channel where sends suspend when
    /// the buffer is full (backpressure) and receives suspend when empty.
    ///
    /// ## Pattern
    /// - Producers call `send(_:)` (async, suspends when full)
    /// - Consumer calls `receive()` (async, suspends when empty)
    ///
    /// ## Single-Consumer Invariant
    /// Only one task may call `receive()` at a time. Concurrent `receive()` calls
    /// result in undefined behavior (debug builds trigger a precondition failure).
    ///
    /// ## Usage
    /// ```swift
    /// let channel = Async.Channel.Bounded<Message>(capacity: 10)
    ///
    /// // Producer (may suspend if buffer full)
    /// await channel.send(message)
    /// channel.close()
    ///
    /// // Consumer (single task, async)
    /// while let msg = await channel.receive() {
    ///     process(msg)
    /// }
    /// ```
    ///
    /// ## Thread Safety
    /// All operations are protected by an internal mutex.
    /// Uses `@unchecked Sendable` because internal state is protected
    /// by mutex synchronization.
    public final class Bounded<Element: Sendable>: @unchecked Sendable {
        private let _state: Mutex<State>
        private let capacity: Int

        /// Creates a new bounded channel with the specified capacity.
        ///
        /// - Parameter capacity: The maximum number of elements that can be buffered.
        ///   Must be greater than zero.
        public init(capacity: Int) {
            precondition(capacity > 0, "Bounded channel capacity must be greater than zero")
            self.capacity = capacity
            self._state = Mutex(State())
        }
    }
}

// MARK: - State

extension Async.Channel.Bounded {
    struct State {
        var buffer: Deque<Element> = .init()
        var sendWaiters: Deque<(element: Element, continuation: CheckedContinuation<Bool, Never>)> = .init()
        var receiveWaiter: CheckedContinuation<Element?, Never>?
        var isClosed: Bool = false
        #if DEBUG
        var hasWaitingConsumer: Bool = false
        #endif
    }
}

// MARK: - Send

extension Async.Channel.Bounded {
    /// Send accessor for grouped operations.
    public var send: Send { Send(channel: self) }

    /// Send namespace providing send operations.
    public struct Send: Sendable {
        let channel: Async.Channel.Bounded<Element>

        init(channel: Async.Channel.Bounded<Element>) {
            self.channel = channel
        }

        /// Send an element, suspending if the buffer is full.
        ///
        /// - Parameter element: The element to send.
        /// - Returns: `true` if the element was sent, `false` if the channel is closed.
        public func callAsFunction(_ element: Element) async -> Bool {
            // Fast path: try immediate send
            let immediateResult: Bool? = channel._state.withLock { state -> Bool? in
                guard !state.isClosed else { return false }

                // If a receiver is waiting, deliver directly
                if let continuation = state.receiveWaiter {
                    state.receiveWaiter = nil
                    #if DEBUG
                    state.hasWaitingConsumer = false
                    #endif
                    continuation.resume(returning: element)
                    return true
                }

                // If buffer has space, add to buffer
                if state.buffer.count < channel.capacity {
                    state.buffer.push.back(element)
                    return true
                }

                // Need to wait
                return nil
            }

            if let result = immediateResult {
                return result
            }

            // Slow path: wait for space
            return await withCheckedContinuation { continuation in
                let shouldResume: Bool? = channel._state.withLock { state -> Bool? in
                    guard !state.isClosed else { return false }

                    // Check again - receiver might have arrived
                    if let recvCont = state.receiveWaiter {
                        state.receiveWaiter = nil
                        #if DEBUG
                        state.hasWaitingConsumer = false
                        #endif
                        recvCont.resume(returning: element)
                        return true
                    }

                    // Check again - space might be available
                    if state.buffer.count < channel.capacity {
                        state.buffer.push.back(element)
                        return true
                    }

                    // Enqueue waiter
                    state.sendWaiters.push.back((element, continuation))
                    return nil
                }

                if let result = shouldResume {
                    continuation.resume(returning: result)
                }
            }
        }

        /// Try to send an element without suspending.
        ///
        /// - Parameter element: The element to send.
        /// - Returns: `true` if the element was sent, `false` if the channel is full or closed.
        public func tryOne(_ element: Element) -> Bool {
            channel._state.withLock { state -> Bool in
                guard !state.isClosed else { return false }

                // If a receiver is waiting, deliver directly
                if let continuation = state.receiveWaiter {
                    state.receiveWaiter = nil
                    #if DEBUG
                    state.hasWaitingConsumer = false
                    #endif
                    continuation.resume(returning: element)
                    return true
                }

                // If buffer has space, add to buffer
                if state.buffer.count < channel.capacity {
                    state.buffer.push.back(element)
                    return true
                }

                return false
            }
        }
    }
}

// MARK: - Receive

extension Async.Channel.Bounded {
    /// Receive accessor for grouped operations.
    public var receive: Receive { Receive(channel: self) }

    /// Receive namespace providing receive operations.
    public struct Receive: Sendable {
        let channel: Async.Channel.Bounded<Element>

        init(channel: Async.Channel.Bounded<Element>) {
            self.channel = channel
        }

        /// Receive the next element from the channel.
        ///
        /// Suspends if the buffer is empty and the channel is not closed.
        /// Returns `nil` when the channel is closed and all elements have been drained.
        ///
        /// - Important: Only one task may call this method at a time.
        ///   Concurrent calls result in undefined behavior.
        ///
        /// - Returns: The next element, or `nil` if closed and drained.
        public func callAsFunction() async -> Element? {
            await withCheckedContinuation { continuation in
                let (shouldSuspend, immediateResult): (Bool, Element??) = channel._state.withLock { state in
                    #if DEBUG
                    precondition(
                        !state.hasWaitingConsumer,
                        "Channel.Bounded: concurrent receive() calls detected - single-consumer invariant violated"
                    )
                    #endif

                    // If buffer has elements, take from buffer
                    if let element = state.buffer.take.front {
                        // Wake up a waiting sender if any
                        if let waiter = state.sendWaiters.take.front {
                            state.buffer.push.back(waiter.element)
                            waiter.continuation.resume(returning: true)
                        }

                        return (false, Optional<Element?>.some(element))
                    }

                    // If there are waiting senders, take directly from them
                    if let waiter = state.sendWaiters.take.front {
                        waiter.continuation.resume(returning: true)
                        return (false, Optional<Element?>.some(waiter.element))
                    }

                    // If closed, return nil
                    if state.isClosed {
                        return (false, Optional<Element?>.some(nil))
                    }

                    // Need to wait
                    state.receiveWaiter = continuation
                    #if DEBUG
                    state.hasWaitingConsumer = true
                    #endif
                    return (true, nil)
                }

                if !shouldSuspend {
                    continuation.resume(returning: immediateResult ?? nil)
                }
            }
        }

        /// Try to receive an element without suspending.
        ///
        /// - Returns: The next element if available, `nil` if the buffer is empty.
        public func tryOne() -> Element? {
            channel._state.withLock { state -> Element? in
                // If buffer has elements, take from buffer
                if let element = state.buffer.take.front {
                    // Wake up a waiting sender if any
                    if let waiter = state.sendWaiters.take.front {
                        state.buffer.push.back(waiter.element)
                        waiter.continuation.resume(returning: true)
                    }

                    return element
                }

                // If there are waiting senders, take directly from them
                if let waiter = state.sendWaiters.take.front {
                    waiter.continuation.resume(returning: true)
                    return waiter.element
                }

                return nil
            }
        }
    }
}

// MARK: - Lifecycle

extension Async.Channel.Bounded {
    /// Close the channel, signaling no more elements will be sent.
    ///
    /// After this call:
    /// - Any pending `receive()` returns `nil` (if buffer empty)
    /// - Future `receive()` calls drain buffer then return `nil`
    /// - Future `send()` calls return `false`
    /// - Pending `send()` calls return `false`
    public func close() {
        let (receiveContToResume, sendWaitersToCancel): (CheckedContinuation<Element?, Never>?, [(Element, CheckedContinuation<Bool, Never>)]) =
            _state.withLock { state in
                state.isClosed = true

                // Cancel all waiting senders
                var waiters: [(Element, CheckedContinuation<Bool, Never>)] = []
                while let waiter = state.sendWaiters.take.front {
                    waiters.append((waiter.element, waiter.continuation))
                }

                // If buffer is empty and receiver is waiting, resume with nil
                if let continuation = state.receiveWaiter, state.buffer.isEmpty {
                    state.receiveWaiter = nil
                    #if DEBUG
                    state.hasWaitingConsumer = false
                    #endif
                    return (continuation, waiters)
                }

                return (nil, waiters)
            }

        receiveContToResume?.resume(returning: nil)
        for (_, continuation) in sendWaitersToCancel {
            continuation.resume(returning: false)
        }
    }

    /// Whether the channel has been closed.
    ///
    /// Note: Even when `true`, `receive()` may still return elements
    /// if the buffer is not yet drained.
    public var isClosed: Bool {
        _state.withLock { $0.isClosed }
    }
}
