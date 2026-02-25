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
    /// Transforms each element and discards `nil` results, preserving caller isolation.
    ///
    /// This overload accepts a synchronous closure and wins overload resolution
    /// over the stdlib's `@Sendable (Element) async -> Output?` variant. The closure
    /// is called synchronously from within the nonsending `next()`, so it runs
    /// inline on the caller's actor — no executor hop.
    ///
    /// - Parameter transform: A closure that transforms each element into an optional output.
    /// - Returns: A concrete `Async.CompactMap` sequence.
    @inlinable
    public func compactMap<Output>(
        _ transform: @escaping (Element) -> Output?
    ) -> Async.CompactMap<Self, Output> {
        Async.CompactMap(base: self, transform: .sync(transform))
    }

    /// Transforms each element with an async closure and discards `nil` results,
    /// preserving caller isolation.
    ///
    /// The closure is nonsending under `NonisolatedNonsendingByDefault` and inherits
    /// the caller's actor isolation when called from `next()`.
    ///
    /// - Parameter transform: An async closure that transforms each element into an optional output.
    /// - Returns: A concrete `Async.CompactMap` sequence.
    @inlinable
    public func compactMap<Output>(
        _ transform: @escaping (Element) async -> Output?
    ) -> Async.CompactMap<Self, Output> {
        Async.CompactMap(base: self, transform: .async(transform))
    }
}
