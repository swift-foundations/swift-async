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

// MARK: - Timer Method (Void)

extension Async.Stream {
    /// Creates a stream that emits once after a delay.
    ///
    /// ## Usage
    /// ```swift
    /// for await _ in Async.Stream<Void>.timer(after: .seconds(5)) {
    ///     print("Timer fired!")
    /// }
    /// ```
    ///
    /// - Parameter delay: The delay before emission.
    /// - Returns: A stream that emits once after the delay.
    public static func timer(after delay: Duration) -> Self where Element == Void {
        Self {
            let state = Async.Stream<Void>.Timer.State(delay: delay)
            return Iterator {
                await state.next()
            }
        }
    }
}

// MARK: - Timer Method (with value)

extension Async.Stream {
    /// Creates a stream that emits a value once after a delay.
    ///
    /// ## Usage
    /// ```swift
    /// for await msg in Async.Stream.timer(after: .seconds(1), value: "Hello") {
    ///     print(msg)  // "Hello" after 1 second
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - delay: The delay before emission.
    ///   - value: The value to emit.
    /// - Returns: A stream that emits the value once after the delay.
    public static func timer(after delay: Duration, value: Element) -> Self {
        Self {
            let state = Async.Stream<Element>.Timer.Value.State(delay: delay, value: value)
            return Iterator {
                await state.next()
            }
        }
    }
}
