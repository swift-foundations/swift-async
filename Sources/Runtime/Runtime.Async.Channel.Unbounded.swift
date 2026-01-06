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

extension Runtime.Async.Channel {
    /// Unbounded MPSC channel with async receive.
    ///
    /// Provides a multi-producer, single-consumer channel with unlimited
    /// buffering capacity. Sends are synchronous and never block. Receives
    /// are asynchronous and suspend until an element is available.
    ///
    /// ## Pattern
    /// - Producers call `send(_:)` (synchronous, never blocks)
    /// - Consumer calls `receive()` (async, suspends until element available)
    ///
    /// ## Single-Consumer Invariant
    /// Only one task may call `receive()` at a time. Concurrent `receive()` calls
    /// result in undefined behavior (debug builds trigger a precondition failure).
    ///
    /// ## Usage
    /// ```swift
    /// let channel = Runtime.Async.Channel.Unbounded<Message>()
    ///
    /// // Producer (any thread, sync)
    /// channel.send(message)
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
    public final class Unbounded<Element: Sendable>: @unchecked Sendable {
        private let _state: Mutex<State>

        /// Creates a new unbounded channel.
        public init() {
            self._state = Mutex(State())
        }
    }
}

// MARK: - State

extension Runtime.Async.Channel.Unbounded {
    struct State {
        var buffer: Deque<Element> = .init()
        var receiveWaiter: CheckedContinuation<Element?, Never>?
        var isClosed: Bool = false
        #if DEBUG
        var hasWaitingConsumer: Bool = false
        #endif
    }
}

// MARK: - Send

extension Runtime.Async.Channel.Unbounded {
    /// Send an element to the channel.
    ///
    /// If a consumer is awaiting via `receive()`, resumes it immediately.
    /// Otherwise, queues the element for later consumption.
    ///
    /// - Parameter element: The element to send.
    /// - Returns: `true` if the element was accepted, `false` if the channel is closed.
    @discardableResult
    public func send(_ element: Element) -> Bool {
        let continuationToResume: CheckedContinuation<Element?, Never>? = _state.withLock { state in
            guard !state.isClosed else { return nil }
            if let continuation = state.receiveWaiter {
                state.receiveWaiter = nil
                #if DEBUG
                state.hasWaitingConsumer = false
                #endif
                return continuation
            } else {
                state.buffer.push.back(element)
                return nil
            }
        }
        if let continuation = continuationToResume {
            continuation.resume(returning: element)
            return true
        }
        return _state.withLock { !$0.isClosed }
    }

    /// Send multiple elements to the channel.
    ///
    /// Efficiently transfers a batch without per-element overhead.
    /// If a consumer is awaiting, resumes with the first element
    /// and queues the rest.
    ///
    /// - Parameter elements: The elements to send.
    /// - Returns: `true` if the elements were accepted, `false` if the channel is closed.
    @discardableResult
    public func send<S: Sequence>(contentsOf elements: S) -> Bool where S.Element == Element {
        let array = Array(elements)
        guard !array.isEmpty else { return !isClosed }

        let first = array[0]
        let (continuationToResume, firstElement): (CheckedContinuation<Element?, Never>?, Element?) =
            _state.withLock { state in
                guard !state.isClosed else { return (nil, nil) }
                if let continuation = state.receiveWaiter {
                    state.receiveWaiter = nil
                    #if DEBUG
                    state.hasWaitingConsumer = false
                    #endif
                    // Resume with first, queue rest
                    for element in array.dropFirst() {
                        state.buffer.push.back(element)
                    }
                    return (continuation, first)
                } else {
                    for element in array {
                        state.buffer.push.back(element)
                    }
                    return (nil, nil)
                }
            }
        if let continuation = continuationToResume, let element = firstElement {
            continuation.resume(returning: element)
            return true
        }
        return !isClosed
    }
}

// MARK: - Receive

extension Runtime.Async.Channel.Unbounded {
    /// Receive accessor for grouped operations.
    public var receive: Receive { Receive(channel: self) }

    /// Receive namespace providing receive operations.
    public struct Receive: Sendable {
        let channel: Runtime.Async.Channel.Unbounded<Element>

        init(channel: Runtime.Async.Channel.Unbounded<Element>) {
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
                        "Channel.Unbounded: concurrent receive() calls detected - single-consumer invariant violated"
                    )
                    #endif

                    if let element = state.buffer.take.front {
                        return (false, Optional<Element?>.some(element))
                    }
                    if state.isClosed {
                        return (false, Optional<Element?>.some(nil))
                    }
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
                state.buffer.take.front
            }
        }
    }
}

// MARK: - Lifecycle

extension Runtime.Async.Channel.Unbounded {
    /// Close the channel, signaling no more elements will be sent.
    ///
    /// After this call:
    /// - Any pending `receive()` returns `nil` (if buffer empty)
    /// - Future `receive()` calls drain buffer then return `nil`
    /// - Future `send()` calls return `false`
    public func close() {
        let continuationToResume: CheckedContinuation<Element?, Never>? = _state.withLock { state in
            state.isClosed = true
            if let continuation = state.receiveWaiter, state.buffer.isEmpty {
                state.receiveWaiter = nil
                #if DEBUG
                state.hasWaitingConsumer = false
                #endif
                return continuation
            }
            return nil
        }
        continuationToResume?.resume(returning: nil)
    }

    /// Whether the channel has been closed.
    ///
    /// Note: Even when `true`, `receive()` may still return elements
    /// if the buffer is not yet drained.
    public var isClosed: Bool {
        _state.withLock { $0.isClosed }
    }
}
