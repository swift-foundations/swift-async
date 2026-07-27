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
internal import Standard_Library_Extensions

extension Async.Stream {
    /// Namespace for replay operations.
    public enum Replay {}
}

// MARK: - Replay Method

extension Async.Stream {
    /// Replays the last N elements to new subscribers.
    ///
    /// Creates a shared stream that buffers recent elements and
    /// replays them to late subscribers.
    ///
    /// ## Usage
    /// ```swift
    /// let replayed = stream.replay(bufferSize: 3)
    ///
    /// // First subscriber sees: 1, 2, 3, 4, 5
    /// // Late subscriber sees: 3, 4, 5 (last 3) + future elements
    /// ```
    ///
    /// - Parameter bufferSize: Maximum number of elements to buffer.
    /// - Returns: A stream that replays buffered elements to new subscribers.
    public func replay(bufferSize: Int) -> Self {
        replayForTesting(bufferSize: bufferSize).stream
    }

    /// Package-visible testing hook (F-003 regression coverage): identical to
    /// `replay(bufferSize:)`, but also returns a closure that reports the
    /// current subscription count, so tests can assert on subscription-list
    /// cleanup without the internal `State` type itself appearing in a
    /// `package`-level signature. Not part of the public API.
    package func replayForTesting(bufferSize: Int) -> (stream: Self, subscriptionCount: @Sendable () async -> Int) {
        let state = Async.Stream<Element>.Replay.State(bufferSize: bufferSize)

        // Start forwarding upstream. F-002: the task handle is retained via
        // `Connection` instead of discarded — see
        // Async.Stream.Replay.Connection.swift.
        let forwardingTask = Task { [self] in
            await state.run { state in
                for await element in self {
                    // F-004: awaited so per-subscription delivery order
                    // matches call order — see Async.Stream.Replay.State.swift.
                    await state.send(element)
                }
                await state.finish()
            }
        }
        let connection = Async.Stream<Element>.Replay.Connection(forwardingTask)

        let stream = Self {
            // Create a cursor that lazily subscribes on first next() call
            let wrapper = Async.Stream<Element>.Replay.Cursor(state: state, connection: connection)
            return Iterator {
                await wrapper.next()
            }
        }
        return (stream, { await state.subscriptionCount })
    }
}
