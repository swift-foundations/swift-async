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

extension Async.Stream where Element == Int {
    /// Creates a stream that emits sequential integers at regular intervals.
    ///
    /// Starts emitting immediately with 0, then increments after each interval.
    ///
    /// ## Usage
    /// ```swift
    /// for await tick in Async.Stream.interval(.seconds(1)) {
    ///     print("Tick \(tick)")  // 0, 1, 2, 3...
    /// }
    /// ```
    ///
    /// - Parameter duration: The interval between emissions.
    /// - Returns: A stream that emits 0, 1, 2, ... at each interval.
    public static func interval(_ duration: Duration) -> Self {
        Self {
            let state = Async.Stream<Int>.Interval.State(duration: duration)
            return Iterator {
                await state.next()
            }
        }
    }
}
