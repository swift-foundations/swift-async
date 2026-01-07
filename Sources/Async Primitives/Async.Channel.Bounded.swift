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
    /// Only one task may call `receive()` at a time.
    ///
    /// ## Usage
    /// ```swift
    /// let channel = Async.Channel.Bounded<Message>(capacity: 10)
    ///
    /// // Producer (may suspend if buffer full)
    /// try await channel.send(message)
    /// channel.close()
    ///
    /// // Consumer (single task, async)
    /// while let msg = try await channel.receive() {
    ///     process(msg)
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// Operations use typed throws for exhaustive error handling:
    /// ```swift
    /// do {
    ///     try await channel.send(value)
    /// } catch .closed {
    ///     // Channel was closed
    /// } catch .cancelled {
    ///     // Task was cancelled
    /// }
    /// ```
    ///
    /// ## Thread Safety
    /// All operations are protected by an internal mutex.
    public final class Bounded<Element: Sendable>: @unchecked Sendable {
        @usableFromInline
        let storage: Storage

        /// Creates a new bounded channel with the specified capacity.
        ///
        /// - Parameter capacity: The maximum number of elements that can be buffered.
        ///   Must be greater than zero.
        public init(capacity: Int) {
            precondition(capacity > 0, "Bounded channel capacity must be greater than zero")
            self.storage = Storage(capacity: capacity)
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
    /// - Future `send()` calls throw `Error.closed`
    /// - Pending `send()` calls throw `Error.closed`
    public func close() {
        let closeAction = storage.withLock { state in
            state.close()
        }

        // Resume receiver with nil (channel closed)
        closeAction.receiverToResume?.resume(returning: (nil, nil))

        // Cancel all waiting senders
        for continuation in closeAction.sendersToCancel {
            continuation.resume(returning: .closed)
        }
    }

    /// Whether the channel has been closed.
    ///
    /// Note: Even when `true`, `receive()` may still return elements
    /// if the buffer is not yet drained.
    public var isClosed: Bool {
        storage.withLock { $0.isClosed }
    }
}
