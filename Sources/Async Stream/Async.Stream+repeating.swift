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

// MARK: - Repeat Interval Method

extension Async.Stream {
    /// Creates a stream that repeatedly emits a value with a delay between emissions.
    ///
    /// ## Usage
    /// ```swift
    /// for await ping in Async.Stream.repeating("ping", every: .seconds(1)) {
    ///     print(ping)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - value: The value to emit.
    ///   - interval: The delay between emissions.
    ///   - count: Number of times to emit (nil for infinite).
    /// - Returns: A stream that emits the value at intervals.
    public static func repeating(_ value: Element, every interval: Duration, count: Int? = nil) -> Self {
        Self {
            let state = Async.Stream<Element>.Repeat.Interval.State(value: value, interval: interval, count: count)
            return Iterator {
                await state.next()
            }
        }
    }
}
