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

extension Async.Stream.Merge {
    /// Owns the two producer tasks feeding `Merge.State` and ties their
    /// cancellation to this Cursor's lifetime.
    ///
    /// F-002: previously `task1`/`task2` were cancelled only from inside the
    /// returned `Iterator`'s `next()` closure, and only on the path where
    /// `state.receive()` naturally returned `nil` — reachable after F-001's
    /// cancellation fix (consumer-task cancellation) or on completion of both
    /// upstream streams, but NOT if the consumer simply drops the
    /// iterator/stream value without ever calling `next()` again (e.g.
    /// abandons it mid-iteration without cancelling its own Task). `deinit`
    /// here is the backstop: whenever this Cursor is deallocated — through
    /// the `next() == nil` path above, or simply by falling out of scope —
    /// both producer tasks are cancelled.
    @usableFromInline
    actor Cursor {
        @usableFromInline
        let state: Async.Stream<Element>.Merge.State

        @usableFromInline
        let task1: Task<Void, Never>

        @usableFromInline
        let task2: Task<Void, Never>

        @usableFromInline
        init(state: Async.Stream<Element>.Merge.State, task1: Task<Void, Never>, task2: Task<Void, Never>) {
            self.state = state
            self.task1 = task1
            self.task2 = task2
        }

        deinit {
            task1.cancel()
            task2.cancel()
        }
    }
}

extension Async.Stream.Merge.Cursor {
    @usableFromInline
    func next() async -> Element? {
        let result = await state.receive()
        if result == nil {
            task1.cancel()
            task2.cancel()
        }
        return result
    }
}
