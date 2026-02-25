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
    /// Includes only elements matching the predicate, preserving caller isolation.
    ///
    /// This overload accepts a synchronous predicate and wins overload resolution
    /// over the stdlib's `@Sendable (Element) async -> Bool` variant. The predicate
    /// is called synchronously from within the nonsending `next()`, so it runs
    /// inline on the caller's actor — no executor hop.
    ///
    /// - Parameter isIncluded: A closure that returns `true` for elements to keep.
    /// - Returns: A concrete `Async.Filter` sequence.
    @inlinable
    public func filter(
        _ isIncluded: @escaping (Element) -> Bool
    ) -> Async.Filter<Self> {
        Async.Filter(base: self, predicate: .sync(isIncluded))
    }

    /// Includes only elements matching the async predicate, preserving caller isolation.
    ///
    /// The predicate is nonsending under `NonisolatedNonsendingByDefault` and inherits
    /// the caller's actor isolation when called from `next()`.
    ///
    /// - Parameter isIncluded: An async closure that returns `true` for elements to keep.
    /// - Returns: A concrete `Async.Filter` sequence.
    @inlinable
    public func filter(
        _ isIncluded: @escaping (Element) async -> Bool
    ) -> Async.Filter<Self> {
        Async.Filter(base: self, predicate: .async(isIncluded))
    }
}
