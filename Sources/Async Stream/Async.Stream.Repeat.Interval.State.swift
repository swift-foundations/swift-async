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
internal import Clocks_Dependencies

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
        init(value: sending Element, interval: Duration, count: Int?) {
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
            try? await clock.sleep(for: interval)
            if Task.isCancelled { return nil }
        }
        first = false

        return value
    }
}
