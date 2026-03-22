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
internal import Clocks_Dependency

extension Async.Stream.Repeat {
    /// Namespace for repeat with interval.
    public enum Interval {}
}

extension Async.Stream.Repeat.Interval {
    /// Internal state for repeat with interval stream.
    @usableFromInline
    actor State {
        @usableFromInline
        let value: Element

        @usableFromInline
        let interval: Duration

        @usableFromInline
        var remaining: Int?

        @usableFromInline
        var first: Bool = true

        @usableFromInline
        init(value: Element, interval: Duration, count: Int?) {
            self.value = value
            self.interval = interval
            self.remaining = count
        }
    }
}

extension Async.Stream.Repeat.Interval.State {
    @usableFromInline
    func next() async -> Element? {
        @Dependency(\.clock) var clock
        if Task.isCancelled { return nil }
        if let r = remaining {
            if r <= 0 { return nil }
            remaining = r - 1
        }

        if !first {
            try? await clock.sleep(until: clock.now.advanced(by: interval))
            if Task.isCancelled { return nil }
        }
        first = false

        return value
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
