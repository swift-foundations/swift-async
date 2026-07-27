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

extension AsyncSequence {
    /// Transforms each element into an async sequence and flattens the results,
    /// preserving caller isolation.
    ///
    /// This overload accepts a synchronous closure and wins overload resolution
    /// over the stdlib's `@Sendable (Element) async -> Segment` variant. The closure
    /// is called synchronously from within the nonsending `next()`, so it runs
    /// inline on the caller's actor — no executor hop.
    ///
    /// Inner sequences are consumed serially — each inner sequence is fully consumed
    /// before the next base element is transformed.
    ///
    /// - Parameter transform: A closure that transforms each element into an async sequence.
    /// - Returns: A concrete `Async.FlatMap` sequence.
    @inlinable
    public func flatMap<Segment: AsyncSequence>(
        _ transform: @escaping (Element) -> Segment
    ) -> Async.FlatMap<Self, Segment> {
        Async.FlatMap(base: self, transform: .sync(transform))
    }

    /// Transforms each element into an async sequence using an async closure and
    /// flattens the results, preserving caller isolation.
    ///
    /// The closure is nonsending under `NonisolatedNonsendingByDefault` and inherits
    /// the caller's actor isolation when called from `next()`.
    ///
    /// Inner sequences are consumed serially — each inner sequence is fully consumed
    /// before the next base element is transformed.
    ///
    /// - Parameter transform: An async closure that transforms each element into an async sequence.
    /// - Returns: A concrete `Async.FlatMap` sequence.
    @inlinable
    public func flatMap<Segment: AsyncSequence>(
        _ transform: @escaping (Element) async -> Segment
    ) -> Async.FlatMap<Self, Segment> {
        Async.FlatMap(base: self, transform: .async(transform))
    }
}
