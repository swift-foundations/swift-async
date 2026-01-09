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

extension Async.Stream {
    /// Namespace for repeat operations.
    public enum Repeat {}
}

extension Async.Stream.Repeat {
    /// Internal state for repeat stream.
    @usableFromInline
    actor State {
        @usableFromInline
        let value: Element

        @usableFromInline
        var remaining: Int?

        @usableFromInline
        init(value: Element, count: Int?) {
            self.value = value
            self.remaining = count
        }
    }
}

extension Async.Stream.Repeat.State {
    @usableFromInline
    func next() async -> Element? {
        if Task.isCancelled { return nil }
        if let r = remaining {
            if r <= 0 { return nil }
            remaining = r - 1
        }
        return value
    }
}

// MARK: - Repeat Method

extension Async.Stream {
    /// Creates a stream that repeatedly emits a value.
    ///
    /// ## Usage
    /// ```swift
    /// let pings = Async.Stream.repeating("ping", count: 3)
    /// // Emits: "ping", "ping", "ping"
    /// ```
    ///
    /// - Parameters:
    ///   - value: The value to emit.
    ///   - count: Number of times to emit (nil for infinite).
    /// - Returns: A stream that emits the value repeatedly.
    public static func repeating(_ value: Element, count: Int? = nil) -> Self {
        Self {
            let state = Async.Stream<Element>.Repeat.State(value: value, count: count)
            return Iterator {
                await state.next()
            }
        }
    }
}
