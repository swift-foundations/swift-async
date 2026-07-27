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

extension Async.Stream.Share {
    /// Per-subscriber wrapper around a `Broadcast` subscription.
    ///
    /// F-002: previously each `share()` consumer's `Broadcast.Subscription`
    /// was never explicitly cancelled — a consumer that stopped calling
    /// `next()` without exhausting the sequence (e.g. its iteration task was
    /// dropped) left its subscriber entry registered in the `Broadcast`
    /// forever. `deinit` here calls `subscription.cancel()` deterministically
    /// once this Cursor — and therefore the consumer's `Iterator` — is
    /// dropped.
    @usableFromInline
    actor Cursor {
        @usableFromInline
        let subscription: Async.Broadcast<Element>.Subscription

        @usableFromInline
        var iterator: Async.Broadcast<Element>.Subscription.AsyncIterator

        // F-002: keeps the shared upstream-forwarding task alive for as long
        // as this Cursor exists — see Async.Stream.Share.State.swift.
        @usableFromInline
        let keepAlive: Async.Stream<Element>.Share.State

        @usableFromInline
        init(state: Async.Stream<Element>.Share.State) {
            let subscription = state.broadcast.subscribe()
            self.subscription = subscription
            self.iterator = subscription.makeAsyncIterator()
            self.keepAlive = state
        }

        deinit {
            subscription.cancel()
        }
    }
}

extension Async.Stream.Share.Cursor {
    @usableFromInline
    func next() async -> Element? {
        // `AsyncIterator.next()` is `mutating` + `async`; calling it directly
        // on the actor-isolated `var iterator` isn't permitted (no `inout`
        // access across a potential suspension point). Copy out, mutate the
        // local copy, write the result back — safe because this method itself
        // only ever runs one call at a time per the AsyncIteratorProtocol
        // single-consumer contract already documented on `Iterator.Box`.
        var localIterator = iterator
        let result = try? await localIterator.next()
        iterator = localIterator
        return result
    }
}
