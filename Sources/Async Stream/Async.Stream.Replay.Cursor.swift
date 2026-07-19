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
    actor Cursor {
        @usableFromInline
        let state: Async.Stream<Element>.Replay.State

        // F-002: keeps the shared upstream-forwarding task alive for as long
        // as this Cursor exists — see Async.Stream.Replay.Connection.swift.
        @usableFromInline
        let connection: Async.Stream<Element>.Replay.Connection

        @usableFromInline
        var subscription: Async.Stream<Element>.Replay.Subscription?

        @usableFromInline
        init(state: Async.Stream<Element>.Replay.State, connection: Async.Stream<Element>.Replay.Connection) {
            self.state = state
            self.connection = connection
        }

        // F-003: `state.unsubscribe(_:)` used to be dead code — nothing ever
        // called it, so abandoned replay subscriptions stayed registered in
        // `state.subscriptions` forever, forwarded every future element
        // (unboundedly growing their internal `queue` since nothing was ever
        // draining it — see F-004's ordering fix in the same family of
        // files). `deinit` fires deterministically once this Cursor — and
        // therefore the consumer's `Iterator` — is dropped: natural
        // completion, an early `break` out of `for await`, or (after F-001)
        // task cancellation all eventually release it, making unsubscribe
        // live code again.
        deinit {
            if let subscription {
                let state = self.state
                Task { await state.unsubscribe(subscription) }
            }
        }
    }
}

extension Async.Stream.Replay.Cursor {
    @usableFromInline
    func next() async -> Element? {
        if subscription == nil {
            subscription = await state.subscribe()
        }
        return await subscription!.next()
    }
}
