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
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Buffer_Ring_Primitives
internal import Cardinal_Primitives

extension Async.Stream.Replay {
    /// Internal state for replay.
    @usableFromInline
    actor State {
        @usableFromInline
        var ring: Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Bounded

        @usableFromInline
        var subscriptions: [Async.Stream<Element>.Replay.Subscription] = []

        @usableFromInline
        var finished: Bool = false

        @usableFromInline
        init(bufferSize: Int) {
            let capacity = try! Index<Element>.Count(max(1, bufferSize))
            self.ring = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Ring.Bounded(minimumCapacity: capacity)
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
}
