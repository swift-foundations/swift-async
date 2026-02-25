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
    /// Transforms each element using the given closure, preserving caller isolation.
    ///
    /// Unlike the stdlib `map` (which takes `@Sendable`), this overload stores a
    /// plain `(Element) async -> Output` closure. Under `NonisolatedNonsendingByDefault`,
    /// the closure is nonsending and inherits the caller's actor isolation.
    ///
    /// - Parameter transform: A closure that transforms each element.
    /// - Returns: A concrete `Async.Map` sequence.
    @inlinable
    public func map<Output>(
        _ transform: @escaping (Element) async -> Output
    ) -> Async.Map<Self, Output> {
        Async.Map(base: self, transform: transform)
    }
}
