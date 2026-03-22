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

extension Async.Stream.Replay {
    /// Wrapper that lazily subscribes to replay state.
    @usableFromInline
    actor IteratorWrapper {
        @usableFromInline
        let state: Async.Stream<Element>.Replay.State

        @usableFromInline
        var subscription: Async.Stream<Element>.Replay.Subscription?

        @usableFromInline
        init(state: Async.Stream<Element>.Replay.State) {
            self.state = state
        }
    }
}

extension Async.Stream.Replay.IteratorWrapper {
    @usableFromInline
    func next() async -> Element? {
        if subscription == nil {
            subscription = await state.subscribe()
        }
        return await subscription!.next()
    }
}
