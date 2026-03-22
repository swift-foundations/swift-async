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

extension Async.Stream.Unfold {
    /// Internal state for unfold stream.
    @usableFromInline
    actor State<S: Sendable> {
        @usableFromInline
        var state: S

        @usableFromInline
        let nextFn: @Sendable (S) async -> (Element, S)?

        @usableFromInline
        init(initial: sending S, next: @escaping @Sendable (S) async -> (Element, S)?) {
            self.state = initial
            self.nextFn = next
        }
    }
}

extension Async.Stream.Unfold.State {
    @usableFromInline
    func next() async -> Element? {
        if Task.isCancelled { return nil }
        guard let (element, newState) = await self.nextFn(state) else { return nil }
        state = newState
        return element
    }
}
