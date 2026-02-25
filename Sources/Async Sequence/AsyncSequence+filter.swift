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
    /// Unlike the stdlib `filter` (which takes `@Sendable`), this overload stores a
    /// plain `(Element) async -> Bool` closure. Under `NonisolatedNonsendingByDefault`,
    /// the closure is nonsending and inherits the caller's actor isolation.
    ///
    /// - Parameter isIncluded: A closure that returns `true` for elements to keep.
    /// - Returns: A concrete `Async.Filter` sequence.
    @inlinable
    public func filter(
        _ isIncluded: @escaping (Element) async -> Bool
    ) -> Async.Filter<Self> {
        Async.Filter(base: self, isIncluded: isIncluded)
    }
}
