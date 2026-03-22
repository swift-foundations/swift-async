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

        try? await clock.sleep(for: delay)
        if Task.isCancelled { return nil }

        fired = true
        return value
    }
}
