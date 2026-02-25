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
public import Clocks_Dependency

extension Async.Stream.Timer {
    /// Namespace for timer with value.
    public enum Value {}
}

extension Async.Stream.Timer.Value {
    /// Internal state for timer stream with value.
    @usableFromInline
    actor State {
        @usableFromInline
        let delay: Duration

        @usableFromInline
        let value: Element

        @usableFromInline
        var fired: Bool = false

        @usableFromInline
        init(delay: Duration, value: Element) {
            self.delay = delay
            self.value = value
        }
    }
}

extension Async.Stream.Timer.Value.State {
    @usableFromInline
    func next() async -> Element? {
        @Dependency(\.clock) var clock
        if fired { return nil }
        if Task.isCancelled { return nil }

        try? await clock.sleep(until: clock.now.advanced(by: delay))
        if Task.isCancelled { return nil }

        fired = true
        return value
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
