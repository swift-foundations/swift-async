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

extension Async.Stream {
    /// Namespace for timer operations.
    public enum Timer {}
}

extension Async.Stream.Timer where Element == Void {
    /// Internal state for timer stream (Void).
    @usableFromInline
    actor State {
        @usableFromInline
        let delay: Duration

        @usableFromInline
        var fired: Bool = false

        @usableFromInline
        init(delay: Duration) {
            self.delay = delay
        }
    }
}

extension Async.Stream.Timer.State where Element == Void {
    @usableFromInline
    func next() async -> Void? {
        @Dependency(\.clock) var clock
        if fired { return nil }
        if Task.isCancelled { return nil }

        try? await clock.sleep(until: clock.now.advanced(by: delay))
        if Task.isCancelled { return nil }

        fired = true
        return ()
    }
}

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
