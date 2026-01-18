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

public import Reference_Primitives

extension Reference.Indirect.Unchecked where Value: AsyncIteratorProtocol {
    /// Advances to the next element and returns it, or nil if no next element exists.
    ///
    /// This extension enables using `Reference.Indirect.Unchecked` as a boxed async iterator,
    /// allowing non-Sendable iterators to be captured in `@Sendable` closures.
    ///
    /// ## Safety
    ///
    /// - **Single-consumer only.** This method must be called from a single task.
    /// - **NOT thread-safe.** Concurrent calls from multiple tasks will cause data races.
    /// - Do not share this box across multiple `Task` instances that call `next()` concurrently.
    ///
    /// ## Correct Usage
    ///
    /// ```swift
    /// let box = Reference.Indirect.Unchecked(asyncIterator)
    /// Task {
    ///     // Single consumer — safe
    ///     while let value = await box.next() {
    ///         process(value)
    ///     }
    /// }
    /// ```
    @usableFromInline
    func next() async -> Value.Element? {
        try? await indirect.value.next()
    }
}
