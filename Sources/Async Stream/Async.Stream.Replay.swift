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
        let state = Async.Stream<Element>.Replay.State(bufferSize: bufferSize)

        // Start forwarding upstream
        Task { [self] in
            for await element in self {
                await state.send(element)
            }
            await state.finish()
        }

        return Self {
            // Create a cursor that lazily subscribes on first next() call
            let wrapper = Async.Stream<Element>.Replay.Cursor(state: state)
            return Iterator {
                await wrapper.next()
            }
        }
    }
}
