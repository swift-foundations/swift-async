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
        init(delay: Duration, value: sending Element) {
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

        // swift-linter:disable:next try optional
        // REASON: `Clock.Any.sleep` witnesses stdlib `Swift.Clock.sleep`, declared
        // untyped `async throws` — there is no `E` for `do throws(E)` to name
        // (rule-exemptions untyped-callee carve-out, feedback_prefer_typed_throws_over_try_optional).
        try? await clock.sleep(for: delay)
        if Task.isCancelled { return nil }

        fired = true
        return value
    }
}
