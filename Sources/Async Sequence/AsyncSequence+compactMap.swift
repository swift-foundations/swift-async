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
    /// Unlike the stdlib `compactMap` (which takes `@Sendable`), this overload stores a
    /// plain `(Element) async -> Output?` closure. Under `NonisolatedNonsendingByDefault`,
    /// the closure is nonsending and inherits the caller's actor isolation.
    ///
    /// - Parameter transform: A closure that transforms each element into an optional output.
    /// - Returns: A concrete `Async.CompactMap` sequence.
    @inlinable
    public func compactMap<Output>(
        _ transform: @escaping (Element) async -> Output?
    ) -> Async.CompactMap<Self, Output> {
        Async.CompactMap(base: self, transform: transform)
    }
}
