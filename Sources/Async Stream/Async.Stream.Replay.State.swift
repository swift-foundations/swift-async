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
internal import Buffer_Primitive
public import Buffer_Ring_Bounded_Primitive
public import Buffer_Ring_Primitive
internal import Buffer_Ring_Primitives
internal import Cardinal_Primitives
public import Column_Primitives
internal import Memory_Allocator_Primitive
internal import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives

extension Async.Stream.Replay {
    /// Internal state for replay.
    @usableFromInline
    actor State {
        @usableFromInline
        var ring: Column.Ring<Element>.Bounded

        @usableFromInline
        var subscriptions: [Async.Stream<Element>.Replay.Subscription] = []

        @usableFromInline
        var finished: Bool = false

        @usableFromInline
        init(bufferSize: Int) {
            // max(1, …) guarantees a valid ≥1 Count, so this init never throws.
            // swiftlint:disable:next force_try
            let capacity = try! Index<Element>.Count(max(1, bufferSize))
            self.ring = Column.Ring<Element>.Bounded(minimumCapacity: capacity)
        }
    }
}

extension Async.Stream.Replay.State {
    @usableFromInline
    func send(_ element: sending Element) {
        // Evict oldest if at capacity
        if ring.isFull {
            _ = ring.pop.front()
        }
        ring.push.back(element)

        // Forward to all subscriptions
        for subscription in subscriptions {
            subscription.receive(element)
        }
    }

    @usableFromInline
    func finish() {
        finished = true
        for subscription in subscriptions {
            subscription.finish()
        }
    }

    @usableFromInline
    func subscribe() -> Async.Stream<Element>.Replay.Subscription {
        var replay: [Element] = []
        ring.forEach { replay.append($0) }
        let subscription = Async.Stream<Element>.Replay.Subscription(replay: replay, finished: finished)
        if !finished {
            subscriptions.append(subscription)
        }
        return subscription
    }

    @usableFromInline
    func unsubscribe(_ subscription: Async.Stream<Element>.Replay.Subscription) {
        subscriptions.removeAll { $0 === subscription }
    }

    /// Testing hook (F-003 regression coverage): the number of
    /// currently-registered subscriptions. Not part of the public API;
    /// exposed to the package's Tests target only via the `@Sendable`
    /// closure returned from `Async.Stream.replayForTesting(bufferSize:)`,
    /// which keeps this internal `State` type itself out of any `package`
    /// -level signature.
    @usableFromInline
    var subscriptionCount: Int {
        subscriptions.count
    }
}
