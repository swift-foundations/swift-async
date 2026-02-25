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
    /// Unlike the stdlib `flatMap` (which takes `@Sendable`), this overload stores a
    /// plain `(Element) async -> Segment` closure. Under `NonisolatedNonsendingByDefault`,
    /// the closure is nonsending and inherits the caller's actor isolation.
    ///
    /// Inner sequences are consumed serially — each inner sequence is fully consumed
    /// before the next base element is transformed.
    ///
    /// - Parameter transform: A closure that transforms each element into an async sequence.
    /// - Returns: A concrete `Async.FlatMap` sequence.
    @inlinable
    public func flatMap<Segment: AsyncSequence>(
        _ transform: @escaping (Element) async -> Segment
    ) -> Async.FlatMap<Self, Segment> {
        Async.FlatMap(base: self, transform: transform)
    }
}
