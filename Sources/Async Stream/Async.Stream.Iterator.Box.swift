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
public import Reference_Primitives

extension Async.Stream.Iterator {
    /// Internal helper to wrap async iterators for capture in `@Sendable` closures.
    ///
    /// Uses `Reference.Indirect.Unchecked` to allow boxing non-Sendable iterators.
    ///
    /// ## Safety
    ///
    /// - **Single-consumer only.** The boxed iterator must be consumed by a single task.
    /// - **NOT thread-safe.** Concurrent access from multiple tasks causes data races.
    /// - This is an explicit opt-in to bypass Sendable checking.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let box = Async.Stream.Iterator.Box(asyncIterator)
    /// Task {
    ///     while let value = await box.next() {
    ///         // Process value — single consumer is safe
    ///     }
    /// }
    /// ```
    @usableFromInline
    typealias Box<I: AsyncIteratorProtocol> = Reference.Indirect<I>.Unchecked
}
